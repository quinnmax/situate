function out = dir2filenames( directory, varargin )

    % out = dir2filenames( directory );
    % out = dir2filenames( directory, '-r' );
    % out = dir2filenames( directory, '*.jpg' );
    % out = dir2filenames( directory, '*.png', '-r', '*.jpg' );
    %   
    %   out = dir2filenames( '/Users/Max/Dropbox/Projects/situate/', '-r', '*.mat' );
    %   
    
    
    use_recursion = false;
    if any(strcmp(varargin,'-r'))
        use_recursion = true;
    end
    
    format_strs = {};
    temp = cellfun( @(x) strfind(x,'*'), varargin,'UniformOutput',false);
    format_strs = varargin( cellfun(@(x) ~isempty(x), temp ) );
    
    dir_data = dir(directory);
    is_hidden = arrayfun( @(x) strcmp(x.name(1),'.'), dir_data );
    dir_data = dir_data(~is_hidden);
    
    dir_data_folders = dir_data([dir_data.isdir]);
    
    dir_data_files = [];
    if ~isempty(format_strs)
        for fsi = 1:length(format_strs)
            temp = dir(fullfile(directory,format_strs{fsi}));
            if isempty(dir_data_files), dir_data_files = temp;
            else dir_data_files(end+1:end+length(temp)) = temp;
            end
        end
    else
        dir_data_files = dir_data(~[dir_data.isdir]);
    end
    
    out = arrayfun( @(x) fullfile( directory, x.name ), dir_data_files, 'UniformOutput', false );
    
    if use_recursion
        for di = 1:length(dir_data_folders)
            out = [out; dir2filenames( fullfile(directory,dir_data_folders(di).name), varargin{:} ) ];
        end
    end
    
end
    
        
    
    
    
    
    
    
    