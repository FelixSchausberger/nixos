{
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # Commands to run in interactive sessions can go here
      set FILE /tmp/magazino-get-cert-run
      set TODAY (date "+%m/%d/%Y")

      if not test -e $FILE
          /per/repos/magazino/magazino-config/usr/bin/magazino-get-certs

          echo $TODAY >$FILE

          # core

          # load_robot_desc

          # Add ssh key to agent if directory exists
          if test -d $HOME/.ssh
              ssh-add $HOME/.ssh/id_ed25519_magazino_pki
          end

          sudo chmod +0666 /dev/kvm
      end
    '';
  };
}
