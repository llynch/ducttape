# private: pipe stdin through fzf with ducttape's common options
_fzf HEADER *FLAGS:
    @fzf -m --height 40% --no-sort --header '{{HEADER}}' {{FLAGS}}
