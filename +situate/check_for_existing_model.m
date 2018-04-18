
function selected_model_fname = check_for_existing_model( possible_paths, varargin )
% selected_model_fname = check_for_existing_model( possible_paths, field_name_1, data_it_should_match, field_name_2, data_it_should_match, ... );
%
%   possible_paths: 
%       directory or cell array of directories to search for .mat files
%   
%   mat files in those directories will be checked for the provided field
%   names, and the data should match the provided data (wrt isequal)
%
%   first match will be returned

    if ~iscell(possible_paths) && isdir(possible_paths)
        possible_paths = {possible_paths};
    end

    selected_model_fname = [];
        
    % possible mat files in specified directories
        mat_files = {};
        for pi = 1:length(possible_paths)
            if isdir(possible_paths{pi})
                temp = dir2filenames( possible_paths{pi}, '*.mat' );
                mat_files = [mat_files temp];
            end
        end
            
    % check for specified fields with matching data
        for mi = 1:length(mat_files)
            matobj = matfile( mat_files{mi} );
            try
                for vari = 1:2:length(varargin)-1
                    file_data =  matobj.(varargin{vari});
                    
                    % for a list of filenames with paths, this forces it to compare only the file names, 
                    % not the whole path and extension 
                    % this was coming up because we were checking that the intended
                    % training images matched against a model trained on a different machine
                    % with a different directory structure. 
                    % however: if images are just numbered, this will be a problem
                    if iscellstr( file_data )   
                        %a = cellfun( @(x) x(last(strfind(x,filesep()))+1:end), file_data, 'UniformOutput', false);
                        a = fileparts_mq( file_data, 'name' );
                        b = fileparts_mq( varargin{vari+1}, 'name' );
                        assert( all(ismember(a,b)) & all(ismember(b,a)) );
                    else
                        assert( isequal( file_data, varargin{vari+1}) );
                    end 

                end

                selected_model_fname = mat_files{mi};
                
                return;

            end
        end
              
end
    
    
    







