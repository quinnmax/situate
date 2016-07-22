
function returned_model = build_box_adjust_models_mq( fnames_lb_train, p )
    
    % define alignment categories
        alignment_descriptions = {'centered','up','down','left','right','expand','contract','background'};
        alignment_enum = [];
        for i = 1:length(alignment_descriptions)
            alignment_enum.(alignment_descriptions{i}) = i;
        end
        
    % define offsets and adjustments that we'll train on
        crops_per_adjustment_type = 6;                                  % defines how many crops of each alignment type are pulled
        offset_scales   = linspace( .2, .7, crops_per_adjustment_type); % these define the offsets for up,down,left,right. in terms of the dimensions of the image. .2 up means .2*crop_height up
        contract_scales = linspace( .2, .7, crops_per_adjustment_type); % these define the box contraction scales. .2 means the box remains centered, but is 20% shorter and 20% narrower
        expand_scales   = linspace( 1.1, 2, crops_per_adjustment_type); % tehse define the expand scales. 1.1 means the box remains centered, but is 110% of the orginal height, and 110% of the original width
        center_peturbation_scale = .1; % center_peturbation_scale * sqrt(w*h) * .3 * randn(1,2); % this slightly perturbs the box centering. this applies to all adjustments, including centered. it's normaly distributed, so mostly very small changes. the parameter sets the (roughly) 98% limit
    
    % define feature extraction method
        feature_extraction_function = @(x) reshape(cnn.cnn_process( x ),1,[]);
        %feature_extraction_function = @(x) rand(1,100);
        
    % allocate for feature vectors
        dummy_image = round(255*rand(100,100,3));
        temp_feature_vector = feature_extraction_function( dummy_image );
        num_features = length(temp_feature_vector );

        crop_features = cell( length(p.situation_objects), length(alignment_descriptions) );
        for oi = 1:length(p.situation_objects)
        for ai = 1:length(alignment_descriptions)
            crop_features{oi,ai} = zeros( length(fnames_lb_train), num_features );
        end
        end

    %% pull crops and get feature vectors
    
    inds_bonked_for_backgrounds = [];
    
    % for each training image
    for imi = 1:length(fnames_lb_train)
        
        cur_fname_lb = fnames_lb_train{imi};
        cur_fname_im = [cur_fname_lb(1:end-4) 'jpg'];
        cur_im = double(imread(cur_fname_im))/255;
        cur_image_data = situate_image_data_label_adjust( situate_image_data(cur_fname_lb), p );

        % for each situation object
        for oi  = 1:length(p.situation_objects)
            
            cur_object = p.situation_objects{oi};
            cur_box_inds = find(strcmp(cur_object, cur_image_data.labels_adjusted),1,'first');
            cur_box_r0rfc0cf = cur_image_data.boxes_r0rfc0cf(cur_box_inds,:);
            crop_w  = cur_box_r0rfc0cf(4) - cur_box_r0rfc0cf(3) + 1;
            crop_h  = cur_box_r0rfc0cf(2) - cur_box_r0rfc0cf(1) + 1;

            % for each alignment
            for cur_alignment = alignment_descriptions
                cur_crops = [];        
                adjustments = [];
                
                % center-peturbed box
                cp = round( center_peturbation_scale * sqrt(crop_w*crop_h) * .3 * randn(crops_per_adjustment_type,2) );
                adjusted_boxes = repmat(cur_box_r0rfc0cf,crops_per_adjustment_type,1);
                adjusted_boxes = adjusted_boxes + [cp(:,1) cp(:,1) cp(:,2) cp(:,2)];
                
                switch cur_alignment{1}
                    
                    case 'centered'
                        adjustments = round([ ...
                            zeros(crops_per_adjustment_type,1) ...
                            zeros(crops_per_adjustment_type,1) ...
                            zeros(crops_per_adjustment_type,1) ...
                            zeros(crops_per_adjustment_type,1) ]);
                    
                    case 'up'
                        adjustments = round([ ...
                            -1*crop_h*reshape(offset_scales,[],1) ...
                            -1*crop_h*reshape(offset_scales,[],1) ...
                            zeros(crops_per_adjustment_type,1) ...
                            zeros(crops_per_adjustment_type,1) ]);
                       
                    case 'down'
                        adjustments = round([ ...
                            crop_h*reshape(offset_scales,[],1) ...
                            crop_h*reshape(offset_scales,[],1) ...
                            zeros(crops_per_adjustment_type,1) ...
                            zeros(crops_per_adjustment_type,1) ]);
                        
                    case 'left'
                        adjustments = round([ ...
                            zeros(crops_per_adjustment_type,1) ...
                            zeros(crops_per_adjustment_type,1) ...
                            -1*crop_w*reshape(offset_scales,[],1) ...
                            -1*crop_w*reshape(offset_scales,[],1) ]);
                       
                    case 'right'
                        adjustments = round([ ...
                            zeros(crops_per_adjustment_type,1) ...
                            zeros(crops_per_adjustment_type,1) ...
                            crop_w*reshape(offset_scales,[],1) ...
                            crop_w*reshape(offset_scales,[],1) ]);
                        
                    case 'expand'
                        adjustments = round([ ...
                            -crop_h*(expand_scales' - 1)/2, ...
                             crop_h*(expand_scales' - 1)/2, ...
                            -crop_w*(expand_scales' - 1)/2, ...
                             crop_w*(expand_scales' - 1)/2  ]);
                        
                    case 'contract'
                        adjustments = round([ ...
                            crop_h*(1-contract_scales')/2, ...
                           -crop_h*(1-contract_scales')/2, ...
                            crop_w*(1-contract_scales')/2, ...
                           -crop_w*(1-contract_scales')/2  ]);
                       
                    case 'background'
                        [~, cur_crops] = situate_crop_extractor( cur_fname_lb, cur_object, p, crops_per_adjustment_type );
                        if length(cur_crops) < crops_per_adjustment_type
                            warning([cur_fname_im ' had trouble producing backbround crops']);
                            % not totally sure what to do when this
                            % happens. we want to have enough background
                            % crops, but some images really can't produce
                            % them. just skip and have fewer examples?
                        end
                    otherwise
                        error('unknown adjustment string');
                end
                
                if isempty(cur_crops)
                    % correct for image edge colisions
                    adjusted_boxes = adjusted_boxes + adjustments;
                    adjusted_boxes(:,1) = max(adjusted_boxes(:,1),1);
                    adjusted_boxes(:,2) = min(adjusted_boxes(:,2),cur_image_data.im_h);
                    adjusted_boxes(:,3) = max(adjusted_boxes(:,3),1);
                    adjusted_boxes(:,4) = min(adjusted_boxes(:,4),cur_image_data.im_w);
                    % pull crops
                    cur_crops = cellfun( @(x) cur_im(x(1):x(2),x(3):x(4),:), num2cell(adjusted_boxes,2), 'UniformOutput', false ); 
                else
                    % we used the situate_crop_extractor, so already have
                    % crops
                end
                
                % get features
                cur_features_cell = cellfun( feature_extraction_function, cur_crops, 'UniformOutput', false );
                % store into crop features data
                row_start  = (imi-1) * crops_per_adjustment_type + 1;
                row_finish = row_start + crops_per_adjustment_type - 1;
                if alignment_enum.(cur_alignment{1}) == 8;
                    temp_mat = cell2mat(cur_features_cell');
                else
                    temp_mat = cell2mat( cur_features_cell );
                end
                crop_features{oi,alignment_enum.(cur_alignment{1})}(row_start:row_finish,:) = temp_mat;
            
            end % alignments
           
        end % situation objects

        progress(imi,length(fnames_lb_train),'box adjust model, pulling crops, getting cnn features: ');
        
    end % training images
    
    assert(isempty(inds_bonked_for_backgrounds));
    % if this bonks, we'll have some empty entries in our background data
    % set for an image. we should give that a look at some point
    
    
    
    %% train the 1v1 models
    
    pairs = nchoosek(alignment_descriptions,2);
    box_adjustment_models_1v1 = cell( length(p.situation_objects), length(pairs) );
    box_adjustment_models_1v1_descriptions = cell( length(p.situation_objects), length(pairs) );
    for oi = 1:length(p.situation_objects)
    for pi = 1:length(pairs)
        
        tic;
            
        alignment_ind_a = alignment_enum.(pairs{pi,1});
        alignment_ind_b = alignment_enum.(pairs{pi,2});
            
        cur_data_a = crop_features{oi,alignment_ind_a};
        cur_data_b = crop_features{oi,alignment_ind_b};
        cur_data   = [cur_data_a; cur_data_b];

        labels_a   = repmat(pairs(pi,1),size(cur_data_a,1),1);
        labels_b   = repmat(pairs(pi,2),size(cur_data_b,1),1);
        cur_labels = [labels_a; labels_b];
        
        svm_model = fitcsvm(cur_data, cur_labels, 'Standardize', 'on');
        svm_model = fitSVMPosterior(svm_model);

        box_adjustment_models_1v1{oi,pi} = svm_model.compact;
        box_adjustment_models_1v1_descriptions{oi,pi} = [p.situation_objects{oi} pairs(pi,:)];
            
        display( ['for ' p.situation_objects{oi} ', training ' pairs{pi,1} ' vs ' pairs{pi,2} ' ' num2str(toc) ' seconds' ]);
            
    end
    end
    
    display('boop');
    
    
    % store in a single struct, append fnames_train, and exit
    
    returned_model.objects_in_indexing_order                = p.situation_objects;
    returned_model.alignments_in_indexing_order             = alignment_descriptions;
    returned_model.box_adjustment_models_1v1                = box_adjustment_models_1v1;
    returned_model.box_adjustment_models_1v1_descriptions   = box_adjustment_models_1v1_descriptions;
    returned_model.feature_extraction_function              = feature_extraction_function;
    
end



    
