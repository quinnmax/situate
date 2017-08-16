
function selected_model_fname = check_for_existing_model( possible_paths, varargin )
% selected_model_fname = check_for_existing_model( possible_paths, field_name_1, data_it_should_match, field_name_2, data_it_should_match, ... );
%
%   possible_paths: 
%       cell array of directories to search for models
%   mat files in those directories will be checked for the provided field
%   names, and the data should match the provided data (wrt isequal)
%
%   first match will be returned

    if ~iscell(possible_paths) && isdir(possible_paths)
        possible_paths = {possible_paths};
    end

    selected_model_fname = [];
    
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
            for mi = 1:length(mat_files)
                matobj = matfile( mat_files{mi} );
                try
                    for vari = 1:2:length(varargin)-1
                        file_data =  matobj.(varargin{vari});
                        % for a list of filenames, this forces ot to check the file names, not the
                        % whole path. this was coming up because we were checking that the intended
                        % training images matched against a model trained on a different machine
                        % with a different directory structure. if images are just numbered, it will
                        % definitely be a problem.
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
    
    
    







