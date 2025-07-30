{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.log-monitor;

  pythonEnv = pkgs.python3.withPackages (ps:
    with ps; [
      requests
      schedule
      openai
    ]);

  logMonitorScript = pkgs.writeText "log_monitor.py" ''
    #!/usr/bin/env python3
    """
    Daily Log Monitor and AI Summarizer
    Collects Docker logs and fail2ban jail logs, summarizes with AI, and sends to Discord
    """

    import subprocess
    import json
    import logging
    import schedule
    import time
    import requests
    from datetime import datetime, timedelta
    from pathlib import Path
    import os
    from typing import Dict, List, Optional
    import openai
    from dataclasses import dataclass
    import sys

    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler('${cfg.logFile}'),
            logging.StreamHandler()
        ]
    )
    logger = logging.getLogger(__name__)

    @dataclass
    class Config:
        """Configuration settings"""
        discord_webhook_url: str
        openai_api_key: str
        fail2ban_log_path: str = "${cfg.fail2banLogPath}"
        max_log_lines: int = ${toString cfg.maxLogLines}
        summary_max_tokens: int = ${toString cfg.summaryMaxTokens}

    class LogCollector:
        """Handles collection of Docker and fail2ban logs"""

        def __init__(self, config: Config):
            self.config = config
            openai.api_key = config.openai_api_key

        def get_docker_logs(self, hours: int = 24) -> Dict[str, str]:
            """Collect Docker logs from all containers for the last N hours"""
            since_time = datetime.now() - timedelta(hours=hours)
            since_str = since_time.strftime("%Y-%m-%dT%H:%M:%S")

            logs = {}

            try:
                # Get list of all containers
                result = subprocess.run(
                    ["${pkgs.docker}/bin/docker", "ps", "-a", "--format", "{{.Names}}"],
                    capture_output=True,
                    text=True,
                    check=True
                )

                container_names = result.stdout.strip().split('\n')

                for container in container_names:
                    if not container:
                        continue

                    try:
                        # Get logs for each container
                        log_result = subprocess.run(
                            ["${pkgs.docker}/bin/docker", "logs", "--since", since_str, "--tail", str(self.config.max_log_lines), container],
                            capture_output=True,
                            text=True,
                            timeout=30
                        )

                        if log_result.stdout or log_result.stderr:
                            combined_logs = f"STDOUT:\n{log_result.stdout}\n\nSTDERR:\n{log_result.stderr}"
                            logs[container] = combined_logs

                    except subprocess.TimeoutExpired:
                        logger.warning(f"Timeout collecting logs for container: {container}")
                    except subprocess.CalledProcessError as e:
                        logger.warning(f"Error collecting logs for container {container}: {e}")

            except subprocess.CalledProcessError as e:
                logger.error(f"Error listing Docker containers: {e}")

            return logs

        def get_fail2ban_logs(self, hours: int = 24) -> str:
            """Collect fail2ban logs from the last N hours"""
            try:
                # Use journalctl (systemd systems)
                since_time = datetime.now() - timedelta(hours=hours)
                since_str = since_time.strftime("%Y-%m-%d %H:%M:%S")

                try:
                    result = subprocess.run(
                        ["${pkgs.systemd}/bin/journalctl", "-u", "fail2ban", "--since", since_str, "--no-pager"],
                        capture_output=True,
                        text=True,
                        check=True,
                        timeout=30
                    )
                    return result.stdout
                except (subprocess.CalledProcessError, FileNotFoundError):
                    # Fallback to log file parsing
                    return self._parse_fail2ban_logfile(hours)

            except Exception as e:
                logger.error(f"Error collecting fail2ban logs: {e}")
                return ""

        def _parse_fail2ban_logfile(self, hours: int) -> str:
            """Parse fail2ban log file directly"""
            try:
                log_path = Path(self.config.fail2ban_log_path)
                if not log_path.exists():
                    return "fail2ban log file not found"

                cutoff_time = datetime.now() - timedelta(hours=hours)
                relevant_lines = []

                with open(log_path, 'r') as f:
                    for line in f:
                        try:
                            # Parse timestamp from fail2ban log format
                            timestamp_str = line.split(',')[0].split(' ')[0:3]
                            timestamp_str = ' '.join(timestamp_str)
                            log_time = datetime.strptime(f"{datetime.now().year} {timestamp_str}", "%Y %Y-%m-%d %H:%M:%S")

                            if log_time >= cutoff_time:
                                relevant_lines.append(line.strip())
                        except (ValueError, IndexError):
                            continue

                return '\n'.join(relevant_lines)

            except Exception as e:
                logger.error(f"Error parsing fail2ban log file: {e}")
                return ""

    class AIsummarizer:
        """Handles AI summarization of logs using OpenAI"""

        def __init__(self, config: Config):
            self.config = config
            self.client = OpenAI(api_key=config.openai_api_key)

        def summarize_logs(self, docker_logs: Dict[str, str], fail2ban_logs: str) -> str:
            """Generate AI summary of all logs"""
            try:
                # Prepare log content for summarization
                log_content = self._prepare_log_content(docker_logs, fail2ban_logs)

                if not log_content.strip():
                    return "No significant log activity in the last 24 hours."

                prompt = self._create_summary_prompt(log_content)

                response = openai.ChatCompletion.create(
                    model="gpt-3.5-turbo",
                    messages=[
                        {"role": "system", "content": "You are a system administrator assistant that analyzes server logs and provides concise, actionable summaries."},
                        {"role": "user", "content": prompt}
                    ],
                    max_tokens=self.config.summary_max_tokens,
                    temperature=0.3
                )

                return response.choices[0].message.content.strip()

            except Exception as e:
                logger.error(f"Error generating AI summary: {e}")
                return f"Error generating summary: {str(e)}"

        def _prepare_log_content(self, docker_logs: Dict[str, str], fail2ban_logs: str) -> str:
            """Prepare and truncate log content for AI processing"""
            content_parts = []

            # Add fail2ban logs
            if fail2ban_logs.strip():
                content_parts.append("=== FAIL2BAN LOGS ===")
                content_parts.append(fail2ban_logs[:5000])  # Limit to prevent token overflow

            # Add docker logs
            if docker_logs:
                content_parts.append("\n=== DOCKER LOGS ===")
                for container, logs in docker_logs.items():
                    if logs.strip():
                        content_parts.append(f"\n--- Container: {container} ---")
                        content_parts.append(logs[:3000])  # Limit per container

            return '\n'.join(content_parts)

        def _create_summary_prompt(self, log_content: str) -> str:
            """Create the prompt for AI summarization"""
            return f"""
    Please analyze the following server logs from the last 24 hours and provide a concise summary including:

    1. Security events (intrusion attempts, banned IPs, etc.)
    2. Application errors or warnings
    3. System performance issues
    4. Notable events or patterns
    5. Recommended actions if any

    Focus on actionable insights and potential issues that need attention.

    LOGS:
    {log_content}

    Please provide a structured summary in markdown format.
    """

    class DiscordNotifier:
        """Handles sending notifications to Discord"""

        def __init__(self, webhook_url: str):
            self.webhook_url = webhook_url

        def send_summary(self, summary: str) -> bool:
            """Send log summary to Discord webhook"""
            try:
                # Split long messages if needed (Discord has 2000 char limit)
                chunks = self._split_message(summary)

                for i, chunk in enumerate(chunks):
                    embed = {
                        "title": f"Daily Log Summary - Part {i+1}/{len(chunks)}" if len(chunks) > 1 else "Daily Log Summary",
                        "description": chunk,
                        "color": 0x00ff00 if "error" not in chunk.lower() and "warning" not in chunk.lower() else 0xff0000,
                        "timestamp": datetime.now().isoformat(),
                        "footer": {
                            "text": f"Generated at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
                        }
                    }

                    payload = {"embeds": [embed]}

                    response = requests.post(
                        self.webhook_url,
                        json=payload,
                        timeout=10
                    )

                    if response.status_code != 204:
                        logger.error(f"Discord webhook failed with status {response.status_code}")
                        return False

                    # Small delay between chunks
                    if len(chunks) > 1:
                        time.sleep(1)

                logger.info("Successfully sent log summary to Discord")
                return True

            except Exception as e:
                logger.error(f"Error sending to Discord: {e}")
                return False

        def _split_message(self, message: str, max_length: int = 1900) -> List[str]:
            """Split long messages into chunks"""
            if len(message) <= max_length:
                return [message]

            chunks = []
            current_chunk = ""

            for line in message.split('\n'):
                if len(current_chunk) + len(line) + 1 <= max_length:
                    current_chunk += line + '\n'
                else:
                    if current_chunk:
                        chunks.append(current_chunk.strip())
                    current_chunk = line + '\n'

            if current_chunk:
                chunks.append(current_chunk.strip())

            return chunks

    def load_config() -> Config:
        """Load configuration from environment variables"""
        discord_webhook_file = os.getenv('DISCORD_WEBHOOK_FILE')
        openai_key_file = os.getenv('OPENAI_API_KEY_FILE')

        if not discord_webhook_file:
            raise ValueError("DISCORD_WEBHOOK_FILE environment variable is required")
        if not openai_key_file:
            raise ValueError("OPENAI_API_KEY_FILE environment variable is required")

        # Read secrets from files
        with open(discord_webhook_file, 'r') as f:
            discord_webhook = f.read().strip()

        with open(openai_key_file, 'r') as f:
            openai_key = f.read().strip()

        return Config(
            discord_webhook_url=discord_webhook,
            openai_api_key=openai_key
        )

    def run_daily_summary():
        """Main function to run daily log summary"""
        try:
            logger.info("Starting daily log summary")

            config = load_config()
            collector = LogCollector(config)
            summarizer = AIsummarizer(config)
            notifier = DiscordNotifier(config.discord_webhook_url)

            # Collect logs
            logger.info("Collecting Docker logs...")
            docker_logs = collector.get_docker_logs()

            logger.info("Collecting fail2ban logs...")
            fail2ban_logs = collector.get_fail2ban_logs()

            # Generate summary
            logger.info("Generating AI summary...")
            summary = summarizer.summarize_logs(docker_logs, fail2ban_logs)

            # Send to Discord
            logger.info("Sending summary to Discord...")
            success = notifier.send_summary(summary)

            if success:
                logger.info("Daily log summary completed successfully")
            else:
                logger.error("Failed to send summary to Discord")

        except Exception as e:
            logger.error(f"Error in daily summary: {e}")
            # Try to send error notification
            try:
                config = load_config()
                notifier = DiscordNotifier(config.discord_webhook_url)
                notifier.send_summary(f"❌ **Log Monitor Error**\n\nFailed to generate daily summary: {str(e)}")
            except:
                pass

    def main():
        """Main entry point"""
        # Check if this is a test run
        if os.getenv('TEST_RUN') == '1':
            logger.info("Running in test mode - executing single summary")
            run_daily_summary()
            sys.exit(0)

        logger.info("Starting log monitor service")

        # Schedule daily run at 8 AM
        schedule.every().day.at("08:00").do(run_daily_summary)

        logger.info("Scheduled daily log summary at 8:00 AM")

        # Keep the script running
        while True:
            schedule.run_pending()
            time.sleep(60)  # Check every minute

    if __name__ == "__main__":
        main()
  '';
in {
  options.services.log-monitor = {
    enable = mkEnableOption "Daily log monitor and AI summarizer service";

    discordWebhookUrl = mkOption {
      type = types.str;
      description = "Discord webhook URL for sending notifications";
    };

    openaiApiKey = mkOption {
      type = types.str;
      description = "OpenAI API key for log summarization";
    };

    fail2banLogPath = mkOption {
      type = types.str;
      default = "/var/log/fail2ban.log";
      description = "Path to fail2ban log file";
    };

    maxLogLines = mkOption {
      type = types.int;
      default = 10000;
      description = "Maximum number of log lines to collect per container";
    };

    summaryMaxTokens = mkOption {
      type = types.int;
      default = 1000;
      description = "Maximum tokens for AI summary generation";
    };

    logFile = mkOption {
      type = types.str;
      default = "/var/log/log-monitor.log";
      description = "Path to log monitor service log file";
    };

    user = mkOption {
      type = types.str;
      default = "root";
      description = "User to run the log monitor service as";
    };

    group = mkOption {
      type = types.str;
      default = "root";
      description = "Group to run the log monitor service as";
    };
  };

  config = mkIf cfg.enable {
    # Create user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = ["docker" "systemd-journal"];
      description = "Log monitor service user";
    };

    users.groups.${cfg.group} = {};

    # Create log directory
    systemd.tmpfiles.rules = [
      "d /var/log 0755 root root -"
      "f ${cfg.logFile} 0644 ${cfg.user} ${cfg.group} -"
    ];

    # SystemD service
    systemd.services.log-monitor = {
      description = "Daily Log Monitor and AI Summarizer";
      after = ["network.target" "docker.service" "fail2ban.service"];
      wants = ["network.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${pythonEnv}/bin/python ${logMonitorScript}";
        Restart = "always";
        RestartSec = "10";

        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = ["/var/log"];
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
      };

      environment = {
        DISCORD_WEBHOOK_FILE = cfg.discordWebhookUrl;
        OPENAI_API_KEY_FILE = cfg.openaiApiKey;
      };
    };

    systemd.services.log-monitor-test = {
      description = "Test Log Monitor";
      after = ["log-monitor-setup.service"];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${pythonEnv}/bin/python ${logMonitorScript}";
      };
      environment = {
        DISCORD_WEBHOOK_FILE = cfg.discordWebhookUrl;
        OPENAI_API_KEY_FILE = cfg.openaiApiKey;
        TEST_RUN = "1";
      };
    };

    # Ensure required services are available
    warnings =
      optional (!config.virtualisation.docker.enable)
      "log-monitor: Docker service is not enabled, Docker log collection will not work"
      ++ optional (!config.services.fail2ban.enable)
      "log-monitor: fail2ban service is not enabled, security log collection may be limited";
  };
}
