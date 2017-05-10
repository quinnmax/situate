
function selected_model_fname = check_for_existing_model( possible_paths, varargin )
% selected_model_fname = check_for_existing_model( possible_paths, field_name_1, data_it_should_match, field_name_2, data_it_should_match, ... );
%
%   possible_paths: 
%       cell array of directories to search for models
%   mat files in those directories will be checked for the provided field
%   names, and the data should match the provided data (wrt isequal)
%
%   first match will be returned

    % check for existing models that might have the same training data
        
        % possible mat files in specified directories
            mat_files = {};
            for pi = 1:length(possible_paths)
                if isdir(possible_paths{pi})
                    temp = dirfiles( possible_paths{pi}, '.mat' );
                    mat_files = [mat_files temp];
                end
            end
            
        % compare specified fields in proposed file to provided data
            selected_model_fname = '';
            for mi = 1:length(mat_files)
                matobj = matfile( mat_files{mi} );
                try
                    for vari = 1:2:length(varargin)-1
                        file_data =  matobj.(varargin{vari});
                        if iscellstr( file_data )   
                            file_data = cellfun( @(x) x(last(strfind(x,filesep()))+1:end), file_data, 'UniformOutput',false);
                            assert( isequal( sort(file_data), sort(varargin{vari+1}) ) );
                        else
                            assert( isequal( file_data, varargin{vari+1}) );
                        end 
                        
                    end
                    selected_model_fname = mat_files{mi};
                    return;
                    
                end
            end
              
end
    
    
    







