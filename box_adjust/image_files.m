function files = image_files( path )
%IMAGE_FILES Returns a cell array of all the image file paths in a directory. 
    files = map(dir([path '*.jpg']), @(x) [path x.name]);
end

