function out = repath( file, path_patterns, path_to, path_from )
    % out = repath( file_in, path_list_file )
    % out = repath( file_in, path_list_cell )

    
    % list to cell
    if ~iscell( path_patterns )
        temp = jsondecode_file( path_patterns );
        dirs_cell = temp.base_dirs;
        out = repath( file, dirs_cell );
        return;
    end
    assert(iscellstr(path_patterns));
    
    % get path_to and path_from
    if ~exist('path_to','var')
        path_to_ind = find(cellfun( @(x) exist( x, 'dir'), path_patterns ));
        if isempty(path_to_ind)
            out = [];
            return;
        end
        path_to = path_patterns{path_to_ind};
    end
    if ~exist('path_from','var')
        cur_fname = file;
        if iscell(cur_fname), cur_fname = file{1}; end
        path_from_ind = find( cellfun(@(x) ~isempty(strfind( cur_fname, x )), path_patterns),1,'first');
        if isempty(path_to_ind)
            out = [];
            return;
        end
        path_from = path_patterns{path_from_ind};
    end
    
    % apply to each cell entry
    if iscell(file)
        out = cellfun( @(x) repath(x,path_patterns,path_to,path_from), file, 'UniformOutput', false);
        return;
    end
    assert(ischar(file));
    
    % do the actual work
    out = fullfile( path_to, file(numel(path_from):end) );
   
end





