function out = fileparts_mq( file, part )
    
%     [pathstr,name,ext] = fileparts( file );
%     switch part
%         case {'path','pathstr'}
%             out = pathstr;
%         case 'name'
%             out = name;
%         case 'ext'
%             out = ext;
%         case 'name.ext'
%             out = [name '.' ext];
%     end
%
%   if 'file' is a cell, maps to each


    if iscell(file)
        out = cellfun( @(x) fileparts_mq( x, part ), file, 'UniformOutput', false );
        return;
    end


    [pathstr,name,ext] = fileparts( file );
    switch part
        case {'path','pathstr'}
            out = pathstr;
        case {'path/name'}
            out = fullfile(pathstr,name);
        case 'name'
            out = name;
        case 'ext'
            out = ext;
        case 'name.ext'
            out = [name '.' ext];
        otherwise
            error('specified part not recognized');
    end
    
    
end
   