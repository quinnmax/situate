function fnames = image_list( directory, format )

% fnames = image_list( directory, [format] );
% full path and file names. format defaults to '.jpg'

    if ~exist('format','var') || isempty(format)
        format = '.jpg';
    end

    temp = dir([directory '*' format]);
    fnames = cellfun( @(x) [directory x],{temp.name},'UniformOutput',false);
    
end
