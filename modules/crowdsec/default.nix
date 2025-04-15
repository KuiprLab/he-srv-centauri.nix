{
  pkgs,
  inputs,
config,
  ...
}: {
  nixpkgs.overlays = [inputs.crowdsec.overlays.default];
  sops.secrets = {
    "enroll-key" = {
      sopsFile = ./enroll-key.txt;
      key = "";
      format = "binary";
      owner = "crowdsec";
      restartUnits = ["crowdsec.service"];
    };

    "crowdsec-api-key" = {
      sopsFile = ./crowdsec-api-key.txt;
      key = "";
      format = "binary";
      owner = "crowdsec";
      restartUnits = ["crowdsec.service"];
    };
  };

  services.crowdsec-firewall-bouncer = {
    enable = true;
    settings = {
      api_key = "$(cat ${config.sops.secrets."crowdsec-api-key".path})";
      api_url = "http://localhost:8080";
    };
  };

  systemd.services.crowdsec.serviceConfig = {
    ExecStartPre = let
      script = pkgs.writeScriptBin "register-bouncer" ''
        #!${pkgs.runtimeShell}
        set -eu
        set -o pipefail

        if ! cscli bouncers list | grep -q "my-bouncer"; then
          cscli bouncers add "my-bouncer" --key $(cat ${config.sops.secrets."crowdsec-api-key".path}
        fi
      '';
    in ["${script}/bin/register-bouncer"];
  };

  services.crowdsec = let
    yaml = (pkgs.formats.yaml {}).generate;
    acquisitions_file = yaml "acquisitions.yaml" {
      source = "journalctl";
      journalctl_filter = ["_SYSTEMD_UNIT=sshd.service"];
      labels.type = "syslog";
    };
  in {
    enable = true;
    allowLocalJournalAccess = true;
    settings = {
      crowdsec_service.acquisition_path = acquisitions_file;
    };

    enrollKeyFile = "/run/secrets/enroll-key";
    settings = {
      api.server = {
        listen_uri = "127.0.0.1:8080";
      };
    };
  };
}
