class Command
    def initialize( do_proc, undo_proc )
        @do = do_proc
        @undo = undo_proc
    end
    
    def do_command
        @do.call
    end
    
    def undo_command
        @undo.call
    end
end
