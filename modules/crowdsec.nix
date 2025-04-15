{

    sops.secrets."enroll-key" = {
        sopsFile = ./enroll-key.txt;
        key = "";
        format = "binary";
        owner = "crowdsec";
        restartUnits = ["crowdsec.service"];
      };

  services.crowdsec = {
    enable = true;
    enrollKeyFile = "/run/secrets/enroll-key";
    settings = {
      api.server = {
        listen_uri = "127.0.0.1:8080";
      };
    };
  };


}
