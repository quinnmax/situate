
function func_handle = mfile2func( mfile_full_filename )

    [directory, func_name] = fileparts( mfile_full_filename );
    
    addpath( directory );
    
    func_handle = str2func( func_name );
    
end
    






