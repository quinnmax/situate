
function selected_model_fname = check_for_existing_model( possible_paths, fnames_in, model_description )
% selected_model_fname = check_for_existing_model( model_directory,fnames_train_in, [model_description] );
%
% model description is currently unused, but would be a good place for
% something like 'cnnsvm' to specify the model that we're looking for.

    if ~exist('model_description','var') || isempty(model_description)
        model_description = '';
    end

    % get pathless versions of input filenames
        fnames_in_pathless = cell(size(fnames_in));
        for fi = 1:length(fnames_in)
            [~,name,ext] = fileparts(fnames_in{fi});
            fnames_in_pathless{fi} = [name ext];
        end
        
    % check for existing models that might have the same training data
        
        % possible mat files in specified directories
            mat_files = {};
            for pi = 1:length(possible_paths)
                if isdir(possible_paths{pi})
                    temp = dirfiles( possible_paths{pi}, '.mat' );
                    mat_files = [mat_files temp];
                end
            end
            
        % compare training images in mat files to input training images
            training_data_match = false(1,length(mat_files));
            for mi = 1:length(mat_files)
                matobj = matfile( mat_files{mi} );
                try
                    fnames_file = matobj.fnames_lb_train;
                    fnames_file_pathless = cell(size(fnames_file));
                    for fi = 1:length(fnames_file_pathless)
                        [~,name,ext] = fileparts(fnames_file{fi});
                        fnames_file_pathless{fi} = [name ext];
                    end
                    if isequal( sort(fnames_file_pathless), sort(fnames_in_pathless) )
                        training_data_match(mi) = true;
                    end
                end
            end
            
        % if there's a match, return the fname
            if any(training_data_match)
                selected_model_fname = mat_files{ find(training_data_match,1,'first') };
            else
                selected_model_fname = '';
            end
        
end
    
    
    







