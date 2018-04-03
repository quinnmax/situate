function out = isfile( in )

    if ischar(in)
        out = logical( exist(in,'file') & ~isdir(in) );
    else
        out = false;
    end
    
end
        