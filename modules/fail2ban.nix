{


 environment.etc."fail2ban/action.d/geohostsdeny.conf".text = ''
   [Definition]

# Option:  actionstart
# Notes.:  command executed once at the start of Fail2Ban.
# Values:  CMD
#
actionstart = 

# Option:  actionstop
# Notes.:  command executed once at the end of Fail2Ban
# Values:  CMD
#
actionstop = 

# Option:  actioncheck
# Notes.:  command executed once before each actionban command
# Values:  CMD
#
actioncheck = 

# Option:  actionban
# Notes.:  command executed when banning an IP. Take care that the
#          command is executed with Fail2Ban user rights. 
#          Excludes PH|Philippines from banning.
# Tags:    See jail.conf(5) man page
# Values:  CMD
#
actionban = IP=<ip> &&
            COUNTRY=$(geoiplookup $IP | egrep "<country_list>") && [ "$COUNTRY" ] || 
            (printf %%b "<daemon_list>: $IP\n" >> <file>)

# Option:  actionunban
# Notes.:  command executed when unbanning an IP. Take care that the
#          command is executed with Fail2Ban user rights.
# Tags:    See jail.conf(5) man page
# Values:  CMD
#
actionunban = IP=<ip> && sed -i.old /ALL:\ $IP/d <file>

[Init]

# Option:  country_list
# Notes.:  List of exempted countries separated by pipe "|"
# Values:  STR  Default:  
#
country_list = PH|Philippines

# Option:  file
# Notes.:  hosts.deny file path.
# Values:  STR  Default:  /etc/hosts.deny
#
file = /etc/hosts.deny

# Option:  daemon_list
# Notes:   The list of services that this action will deny. See the man page
#          for hosts.deny/hosts_access. Default is all services.
# Values:  STR  Default: ALL
daemon_list = ALL
    '';

  services.fail2ban = {
    enable = true;
    bantime = "24h"; # Ban IPs for one day on the first ban
    banaction = "geohostsdeny";
    bantime-increment = {
      enable = true; # Enable increment of bantime after each violation
      formula = "ban.Time * math.exp(float(ban.Count+1)*banFactor)/math.exp(1*banFactor)";
      maxtime = "168h"; # Do not ban for more than 1 week
      overalljails = true; # Calculate the bantime based on all the violations
    };
  };

}
