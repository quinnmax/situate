
function selected_model_fname = check_for_existing_model( possible_paths, varargin )
% selected_model_fname = check_for_existing_model( possible_paths, field_name_1, data_it_should_match, @comparison_function_1, field_name_2, data_it_should_match, @comparison_function_2 ... );
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
%       @(a,b) all(ismember(fileparts_mq(a,'name.ext'),fileparts_mq(b,'name.ext'))) & all(ismember(fileparts_mq(b,'name.ext'), fileparts_mq(a,'name.ext')))
% 
%   query is a subset of files in the existing file, ignore path, ignore order:
%       @(a,b) all(ismember(fileparts_mq(a,'name.ext'),fileparts(b,'name.ext')))
% 
%   same cell strings, ignore order
%       @(a,b) all(ismember(a,b)) & all(ismember(b,a))
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
                for vari = 1:2:length(varargin)-1
                    file_data =  matobj.(varargin{vari});
                    
                    % for a list of filenames with paths, this forces it to compare only the file names, 
                    % not the whole path and extension 
                    % this was coming up because we were checking that the intended
                    % training images matched against a model trained on a different machine
                    % with a different directory structure. 
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
    
    
    







