
function dir_out = find_base_dir( dir_in )

% dir_out = find_base_dir( dir_in );
% uses base_image_directories.json
    
    if ~exist( dir_in, 'dir' )
        base_image_directories = jsondecode_file('base_image_directories.json');
        base_image_directories = base_image_directories.base_dirs;
        if ~isempty(base_image_directories)
            proposed_directories = cellfun( @(x) exist( fullfile( x, dir_in ), 'dir' ), base_image_directories );
            dir_in = fullfile( base_image_directories{find(proposed_directories,1,'first')}, dir_in );
        else
            error('directory could not be reconciled with base image directory');
        end
        dir_out = dir_in;
    end
    
end