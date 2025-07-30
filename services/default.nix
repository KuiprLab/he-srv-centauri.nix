{config, ...}: {
  imports = [
    ./tailscale.nix
    # ./nginx
    ./haproxy
    ./monitor
  ];

  sops.secrets = {
    "discord-webhook" = {
      sopsFile = ./secrets.yaml;
      owner = config.services.log-monitor.user;
      group = config.services.log-monitor.group;
      mode = "0400";
      restartUnits = ["log-monitor.service"];
    };
    "openai-api-key" = {
      sopsFile = ./secrets.yaml;
      owner = config.services.log-monitor.user;
      group = config.services.log-monitor.group;
      mode = "0400";
      restartUnits = ["log-monitor.service"];
    };
  };

  # Enable and configure the log monitor service
  services.log-monitor = {
    enable = true;
    discordWebhookUrl = config.sops.secrets."discord-webhook".path;
    openaiApiKey = config.sops.secrets."openai-api-key".path;

    # Optional customizations
    fail2banLogPath = "/var/log/fail2ban.log";
    maxLogLines = 10000;
    summaryMaxTokens = 1000;
    logFile = "/var/log/log-monitor.log";
    user = "log-monitor";
    group = "log-monitor";
  };
}
