
function selected_model_fname = check_for_existing_model( possible_paths, varargin )
% selected_model_fname = check_for_existing_model( possible_paths, ...
%   field_name_1, data_it_should_match, @comparison_function_1, ...
%   field_name_2, data_it_should_match, @comparison_function_2, ... );
%
%   possible_paths: 
%       directory or cell array of directories to search for .mat files
%   
% variable_name, value, @comparison_function
%
%   mat files in those directories will be checked for the provided field
%   names, and the data should match the provided data (wrt provided comparison function)
%
%   first match will be returned
% 
% 
% below are some useful comparison functions that i've used
%
%   general isequal
%       @isequal
% 
%   same file list, ignore path, ignore order:
%       @(a,b) isempty(setxor(fileparts_mq(a,'name.ext'),fileparts_mq(b,'name.ext')))
% 
%   query is a subset of files in the existing file, ignore path, ignore order:
%       @(a,b) all(ismember(fileparts_mq(a,'name.ext'),fileparts_mq(b,'name.ext')))
% 
%   same cell strings, ignore order
%       @(a,b) isempty(setxor(a,b))
%   
%   equivalent struct, ignoring Nan and frozen variables in anon functions
%       @isequal_struct


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
                for vari = 1:3:length(varargin)-1
                    file_data =  matobj.(varargin{vari});
                    if( varargin{vari+2}( varargin{vari+1}, file_data ) )
                        % great
                    else
                        % problem
                        assert(false);
                    end
                end

                selected_model_fname = mat_files{mi};
                
                return;
            end
        end
              
end
    
    
    







