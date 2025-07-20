{
  programs.fish = {
    interactiveShellInit = ''
      # Only run in graphical sessions, not TTY
      if test -n "$XDG_SESSION_TYPE"; and test "$XDG_SESSION_TYPE" != "tty"
        # Set environment variables
        set -x IS_ROBOT no
        set -x COLOR_PROMPT yes
        set -x CATKIN_WS "$HOME/catkin_ws/"
        set -x FZF_ENABLED yes
        set -x LD_LIBRARY_PATH /opt/ros/noetic/lib
        set -x PATH "$PATH" "$HOME/.cargo/bin" /usr/local/go/bin
        set -x EDITOR hx

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
      end
    '';
  };
}
