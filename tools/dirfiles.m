function output = dirfiles( directory, file_suffix )
% output = dirfiles( directory, file_suffix );

    if ~strcmp(file_suffix(1),'.')
        file_suffix = ['.' file_suffix];
    end
            
    dirdata = dir( fullfile( directory, ['*' file_suffix]) );
    fnames = {dirdata.name};
    output = cellfun( @(x) fullfile(directory, x), fnames, 'UniformOutput', false );
   
end