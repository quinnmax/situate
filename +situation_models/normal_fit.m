
function situation_model = normal_fit( situation_struct, fnames_in, saved_models_directory )

    % model = normal_fit( situation_struct, data_in );
    %   p should be a Situate parameters struct
    %   data_in can be a cell array of file paths and names of label files, or a directory containing label files

    
    
    model_description = 'normal situation model';
    fnames_in_stripped = fileparts_mq( fnames_in, 'name');
    classes = situation_struct.situation_objects;
    
    if ~exist('saved_models_directory','var') || isempty(saved_models_directory)
        saved_models_directory = 'saved_models/';
    end
    
    
    %% check for empty training data

        if isempty( fnames_in_stripped )
            warning('training fnames were empty, using default situation model for dogwalking');
            selected_model_fname = 'saved_models/unit_test_situation_model_normal.mat';
            situation_model = load( selected_model_fname );
            disp(['loaded ' model_description ' model from: ' selected_model_fname ]);
            return;
        end

    
    
    %% check for existing model
        
        if exist(saved_models_directory,'dir')
            selected_model_fname = ...
                situate.check_for_existing_model( saved_models_directory, ...
                'fnames_lb_train', fnames_in, @(a,b) isempty(setxor(fileparts_mq(a,'name'),fileparts_mq(b,'name'))), ...
                'model_description', model_description, @isequal, ...
                'situation_objects', situation_struct.situation_objects, @(a,b)isempty(setxor(a,b)) );
        else
            selected_model_fname = [];
        end

        if ~isempty(selected_model_fname)
            situation_model = load( selected_model_fname );
            display([ 'loaded ' model_description ' from ' selected_model_fname ]);
            return;
        end

        
        
    %% train

        % get image data from a directory
            image_data = situate.labl_load(fnames_in, situation_struct);

        % turn data into a single matrix
            row_description = {'r0' 'rc' 'rf' 'c0' 'cc' 'cf' 'log w' 'log h' 'log aspect ratio' 'log area ratio'};
            % extra row padding, diff rc1,rc2; diff rc2,rc3; diff rc1,rc3
            num_variables = length(row_description);
            data_pile = zeros( length(image_data), num_variables * length(situation_struct.situation_objects) );
            for ii = 1:length(image_data)
                cur_row = [];
                for oi = 1:length(situation_struct.situation_objects)
                    wi = find( strcmp( image_data(ii).labels_adjusted, situation_struct.situation_objects{oi} ), 1 );
                    box_data = image_data(ii).boxes_normalized_r0rfc0cf(wi,:);
                    r0 = box_data(1);
                    rf = box_data(2);
                    c0 = box_data(3);
                    cf = box_data(4);
                    w = cf - c0;
                    h = rf - r0;
                    rc = r0 + h/2;
                    cc = c0 + w/2;
                    log_aspect_ratio = log( w/h );
                    log_area_ratio   = log( w*h ); % image is unit area, so w*h is area ratio
                    new_entries = [r0 rc rf c0 cc cf log(w) log(h) log_aspect_ratio log_area_ratio];
                    cur_row = [cur_row new_entries ];
                end
                data_pile(ii,:) = cur_row;
            end
    
        % see if the covariance matrix satisfies old man cholesky
            mu = mean(data_pile);
            Sigma = cov(data_pile);
            Sigma = covar_mat_fix(Sigma);


        % gather joint distribution info
            situation_model       = [];
            situation_model.mu    = mu;
            situation_model.Sigma = Sigma;
            situation_model.situation_objects      = situation_struct.situation_objects;
            situation_model.parameters_description = row_description;
            situation_model.fnames_lb_train = sort(fnames_in_stripped);
            situation_model.model_description = model_description;
            situation_model.is_conditional = false;
            
            

        % get estimates of priors for box over .5 iou
            %iou_over_50_rate = nan(numel(image_data),numel(situation_model.situation_objects));
            n = 500;
            num_objs = numel(situation_model.situation_objects);
            num_images = numel(image_data);
            model_normal = situation_model;
            ooi = nan( num_images * n * num_objs, 1 );
            density_normal_sampled_normal_scored                 = nan( numel(image_data) * n, 1 );
            density_conditioned_1a_sampled_conditioned_1a_scored = nan( numel(image_data) * n, 1 );
            density_conditioned_1b_sampled_conditioned_1b_scored = nan( numel(image_data) * n, 1 );
            density_conditioned_2_sampled_conditioned_2_scored   = nan( numel(image_data) * n, 1 );
            ious_normal         = nan( numel(image_data) * n, 1 );
            ious_conditioned_1a = nan( numel(image_data) * n, 1 );
            ious_conditioned_1b = nan( numel(image_data) * n, 1 );
            ious_conditioned_2  = nan( numel(image_data) * n, 1 );

            rows_per_image = n * num_objs;
            
            for ii = 1:num_images
                
                cur_labl = image_data(ii);
                im_row = cur_labl.im_h;
                im_col = cur_labl.im_w;
              
%                 [workspaces_dummy, detected_object_matrix] = make_dummy_workspaces( cur_labl, situation_struct );

                row_start_im = (ii-1) * rows_per_image + 1;
                
                for oi = 1:num_objs
            
                    cur_rows = row_start_im + ( n*(oi-1) : n*oi-1 );
                    
                    % object of interest
                    ooi(cur_rows) = oi;
                    object_type = situation_struct.situation_objects{oi};

                    % get gt box
                    li = strcmp( object_type, cur_labl.labels_adjusted);
                    cur_gt_box_r0rfc0cf = cur_labl.boxes_r0rfc0cf(li,:);

%                     % build conditioning models
%                         other_obj_inds = setsub(1:num_objs,oi);
%                         % obj 1a
%                         workspace_dummy_ind = ~logical(detected_object_matrix(:,oi)) & ~logical(detected_object_matrix(:,other_obj_inds(1))) &  logical(detected_object_matrix(:,other_obj_inds(2)));
%                         model_conditional_1a_dummy = situation_models.normal_condition( model_normal, object_type, workspaces_dummy{workspace_dummy_ind} );
%                         % obj 1b
%                         workspace_dummy_ind = ~logical(detected_object_matrix(:,oi)) &  logical(detected_object_matrix(:,other_obj_inds(1))) & ~logical(detected_object_matrix(:,other_obj_inds(2)));
%                         model_conditional_1b_dummy = situation_models.normal_condition( model_normal, object_type, workspaces_dummy{workspace_dummy_ind} );
%                         % objs 2
%                         workspace_dummy_ind = ~logical(detected_object_matrix(:,oi)) &  logical(detected_object_matrix(:,other_obj_inds(1))) &  logical(detected_object_matrix(:,other_obj_inds(2)));
%                         model_conditional_2_dummy = situation_models.normal_condition( model_normal, object_type, workspaces_dummy{workspace_dummy_ind} );

                    % sample from the models
                        
                        % Normal samples, Normal scores
                        [boxes_r0rfc0cf_normal, temp] = situation_models.normal_sample( model_normal, object_type, n, [im_row im_col]); 
                        density_normal_sampled_normal_scored(cur_rows) = temp;

%                         % Conditional 1a samples, Conditional 1a scores
%                         [boxes_r0rfc0cf_conditioned_1a, temp] = situation_models.normal_sample( model_conditional_1a_dummy, object_type, n, [im_row im_col]); 
%                         density_conditioned_1a_sampled_conditioned_1a_scored(cur_rows) = temp;
% 
%                         % Conditional 1b samples, Conditional 1b scores
%                         [boxes_r0rfc0cf_conditioned_1b, temp] = situation_models.normal_sample( model_conditional_1b_dummy, object_type, n, [im_row im_col]); 
%                         density_conditioned_1b_sampled_conditioned_1b_scored(cur_rows) = temp;
% 
%                         % Conditional 2 samples, Conditional 2 scores
%                         [boxes_r0rfc0cf_conditioned_2, temp] = situation_models.normal_sample( model_conditional_2_dummy, object_type, n, [im_row im_col]); 
%                         density_conditioned_2_sampled_conditioned_2_scored(cur_rows) = temp;

                    % get gt ious of samples
                    
                        % get gt iou of normal samples
                        temp = intersection_over_union( boxes_r0rfc0cf_normal, cur_gt_box_r0rfc0cf, 'r0rfc0cf','r0rfc0cf');
                        ious_normal(cur_rows) = temp;

%                         % get gt iou of conditioned samples samples
%                         temp = intersection_over_union( boxes_r0rfc0cf_conditioned_1a, cur_gt_box_r0rfc0cf, 'r0rfc0cf','r0rfc0cf');
%                         ious_conditioned_1a(cur_rows) = temp;
% 
%                         temp = intersection_over_union( boxes_r0rfc0cf_conditioned_1b, cur_gt_box_r0rfc0cf, 'r0rfc0cf','r0rfc0cf');
%                         ious_conditioned_1b(cur_rows) = temp;
% 
%                         temp = intersection_over_union( boxes_r0rfc0cf_conditioned_2, cur_gt_box_r0rfc0cf, 'r0rfc0cf','r0rfc0cf');
%                         ious_conditioned_2(cur_rows) = temp;

                end
                
                progress(ii,num_images);
                
            end
            
            p_x = nan(1,num_objs);
            bx = nan(1,num_objs);
            iou_dist = cell(1,num_objs);
            bx_dist = cell(1,num_objs);
            for oi = 1:num_objs
                ci = oi == ooi;
                iou_dist{oi} = ious_normal(ci);
                p_x(oi) = mean( ious_normal(ci) > .5 );
                bx(oi) = median( density_normal_sampled_normal_scored(ci) );
                bx_dist{oi} = density_normal_sampled_normal_scored(ci);
            end

            situation_model.p_x = p_x;
            situation_model.bx  = bx;
            situation_model.iou_dist = iou_dist;
            situation_model.bx_dist = bx_dist;
                    
          
     %% save the model
        
        iter = 0;
        if ~exist(saved_models_directory,'dir'), mkdir( saved_models_directory ); end
        saved_model_fname = fullfile( saved_models_directory, [ [classes{:}] ', ' model_description ', ' num2str(iter) '.mat'] );
        while exist(saved_model_fname,'file')
            iter = iter + 1;
            saved_model_fname = fullfile( saved_models_directory, [ [classes{:}] ', ' model_description ', ' num2str(iter) '.mat'] );
        end
        save(saved_model_fname,'-struct','situation_model');
        display(['saved ' model_description ' model to: ' saved_model_fname ]);

    
    
end















