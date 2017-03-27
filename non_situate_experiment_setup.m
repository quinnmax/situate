

% this goes through much of the process of setting up the classifier and
% situation model used in situate. it uses the defualt training/testing
% split and loads the default classifier models.
%
% this is a pretty good place to run classifier experiments and stuff that
% shouldn't use situate's stochastic nature to pull crops.

% to do, bounding box regression
%   do in terms of x center, y center, width, height
%   keep the 4000 entry cnn vector for this
%   keep the fix-this-box delta value
%   include a column for image index
%   include a column for object type
%
% to do, fitting the support functions
%   do in terms of external support without regard for objects in workspace
%   keep sample density
%   keep object type
%   keep IOU
%   keep classifier confidence



%% initialize the situate structures
    
    p = situate.parameters_initialize();
    p.situation_model_fit          = @situation_model_normal_fit;        
    p.situation_model_update       = @situation_model_normal_condition; 
    p.situation_model_sample_box   = @situation_model_normal_aa_sample;  
    
    p.classifier_saved_models_directory = 'default_models/';
    p.classifier_load_or_train = @classifiers.cnnsvm_train;
    p.classifier_apply = @classifiers.cnnsvm_apply;
    
    experiment_settings = [];
    experiment_settings.title               = 'real life classifier activation stats';
    experiment_settings.situations_struct   = situate.situation_definitions();
    experiment_settings.situation           = 'dogwalking'; 
    
    temp = experiment_settings.situations_struct.(experiment_settings.situation);
    p.situation_objects = temp.situation_objects;
    p.situation_objects_possible_labels = temp.situation_objects_possible_labels;
    
    
    
%% find data
    
    try
        data_path = experiment_settings.situations_struct.(experiment_settings.situation).possible_paths{ find(cellfun( @(x) exist(x,'dir'), experiment_settings.situations_struct.(experiment_settings.situation).possible_paths ),1,'first')};
    catch
        while ~exist('data_path','var') || isempty(data_path) || ~isdir(data_path)
            h = msgbox( ['Select directory containing images of ' experiment_settings.situation] );
            uiwait(h);
            data_path = uigetdir(pwd);
        end
    end
    
    split_file_directory = 'default_split/';
    fnames_splits_train = dir(fullfile(split_file_directory, '*_fnames_split_*_train.txt'));
    fnames_splits_test  = dir(fullfile(split_file_directory, '*_fnames_split_*_test.txt' ));
    fnames_splits_train = cellfun( @(x) fullfile(split_file_directory, x), {fnames_splits_train.name}, 'UniformOutput', false );
    fnames_splits_test  = cellfun( @(x) fullfile(split_file_directory, x), {fnames_splits_test.name},  'UniformOutput', false );
    assert( length(fnames_splits_train) > 0 );
    assert( length(fnames_splits_train) == length(fnames_splits_test) );
    fprintf('using training splits from:\n');
    fprintf('\t%s\n',fnames_splits_train{:});
    fprintf('using testing splits from:\n');
    fprintf('\t%s\n',fnames_splits_test{:});
    temp = [];
    temp.fnames_lb_train = cellfun( @(x) importdata(x, '\n'), fnames_splits_train, 'UniformOutput', false );
    temp.fnames_lb_test  = cellfun( @(x) importdata(x, '\n'), fnames_splits_test,  'UniformOutput', false );
    data_folds = [];
    for i = 1:length(temp.fnames_lb_train)
        data_folds(i).fnames_lb_train = temp.fnames_lb_train{i};
        data_folds(i).fnames_lb_test  = temp.fnames_lb_test{i};
        data_folds(i).fnames_im_train = cellfun( @(x) [x(1:end-4) 'jpg'], temp.fnames_lb_train{1}, 'UniformOutput', false );
        data_folds(i).fnames_im_test  = cellfun( @(x) [x(1:end-4) 'jpg'], temp.fnames_lb_test{1},  'UniformOutput', false );
    end
    
    fnames_train = cellfun( @(x) fullfile( data_path, x ), data_folds(1).fnames_lb_train, 'UniformOutput', false );
    fnames_test  = cellfun( @(x) fullfile( data_path, x ), data_folds(1).fnames_lb_test,  'UniformOutput', false );
    
    
    
%% load or train classifier and situation model
    
    classifier_model = p.classifier_load_or_train( p, fnames_train, p.classifier_saved_models_directory );
    situation_model  = p.situation_model_fit( p, fnames_train );
    
    demo_image = repmat( imread('cameraman.tif'),1,1,3);
    cnn_output_size_full = length(cnn.cnn_process(demo_image));
    cnn_output_size_partial = numel(cnn.cnn_process(demo_image,[],15));
    
    
    
%% get stats on shape,size for each object type

    use_resize = true;
    im_data = situate.load_image_and_data(fnames_train, p, use_resize );
    
    box_shapes = nan(length(im_data),length(p.situation_objects));
    box_sizes  = nan(length(im_data),length(p.situation_objects));
    for imi = 1:length(im_data)
        
        cur_im_labels = im_data(imi).labels_adjusted;
        cur_im_shapes = im_data(imi).box_aspect_ratio;
        cur_im_sizes  = im_data(imi).box_area_ratio;
        
        for oi = 1:length(p.situation_objects)
            cur_obj = p.situation_objects{oi};
            cur_obj_ind = find(strcmp(cur_im_labels,cur_obj));
            box_shapes(imi,oi) = cur_im_shapes(cur_obj_ind);
            box_sizes(imi,oi)  = cur_im_sizes(cur_obj_ind);
        end
        
    end 
    
    figure
    for oi = 1:length(p.situation_objects)
        subplot2(4,length(p.situation_objects),1,oi); hist(box_shapes(:,oi),50);
        xlabel('shapes');
        title(p.situation_objects{oi});
        subplot2(4,length(p.situation_objects),2,oi); hist(box_sizes(:,oi),20);
        xlabel('sizes');
        
        subplot2(4,length(p.situation_objects),3,oi); hist(log(box_shapes(:,oi)),50);
        xlabel('log shapes');
        title(p.situation_objects{oi});
        subplot2(4,length(p.situation_objects),4,oi); hist(log(box_sizes(:,oi)),20);
        xlabel('log sizes');
    end
        
    
    
%% define box set for each image

    ind_0s_func = @(c, w) c + [0 -1.5*w -.5*w -.25*w -.125*w  .125*w .25*w .5*w 1.5*w] - w/2;
    ind_fs_func = @(ind_0s,w) max(1,round(ind_0s)) + w - 1;
    
%% for each image
    
    % define the set of boxes
    
    % for each box
    % pull crop
    % apply cnn
    % eval with each object model
    % get gt iou with each object
    
    score_per_obj = cell(1,length(p.situation_objects));
    
    column_descriptions = { ...
        'image index', ...
        'box coordinates r0rfc0cf', ...
        'source object type index (p.situation_objects ordering)', ...
        'source object box r0rfc0cf', ...
        'gt iou with source box', ...
        ...
        'box delta with source box (xc/w yc/h w_scalar h_scalar)', ...
        ...
        'cnn features intermediate (spatial, for bb regression)', ...
        'cnn features final (for classification)', ...
        'classifier confidence', ...
        ...
        'solo density values (in order of situation_objects)', ...
        'single conditioned density values (in order of situation_objects)', ...
        'single conditioned density values (in order of situation_objects)', ...
        'double conditioned density values (in order of situation_objects)' };
    
    data_per_image = [];
    
    %for imi = 1:length(fnames_train)
    for imi = 1:10
    %for imi = 1:2
        
        [~,im] = situate.load_image_and_data(im_data(imi).fname_lb, p, true );
        if max(im(:))<2, im = uint8(fix(mat2gray(im)*255)); end
        
        % boxes and box info for this image
        boxes_to_eval_r0rfc0cf = [];
        box_sources_r0rfc0cf   = [];
        box_source_obj_type    = [];
        
        for oi = 1:length(p.situation_objects)
            
            cur_ob_ind = find(strcmp(p.situation_objects{oi},im_data(imi).labels_adjusted));
            cur_ob_box_r0rfc0cf = im_data(imi).boxes_r0rfc0cf( cur_ob_ind,:);
            r0 = cur_ob_box_r0rfc0cf(1);
            rf = cur_ob_box_r0rfc0cf(2);
            c0 = cur_ob_box_r0rfc0cf(3);
            cf = cur_ob_box_r0rfc0cf(4);
            w = cf - c0 + 1;
            h = rf - r0 + 1;
            rc = r0 + h/2;
            cc = c0 + w/2;
            
            r0s = round( ind_0s_func( rc,  h ) ); 
            c0s = round( ind_0s_func( cc,  w ) ); 
            
            temp_n = length(r0s);
            r0s = sort(repmat(r0s',length(c0s),1));
            c0s = repmat(c0s', temp_n,1);
            
            rfs = round( ind_fs_func( r0s, h ) ); 
            cfs = round( ind_fs_func( c0s, w ) );
            
            ws = cfs - c0s + 1;
            hs = rfs - r0s + 1;
            
            xcs = c0s + ws/2;
            ycs = r0s + hs/2;
            
            new_boxes_to_eval_r0rfc0cf = [r0s rfs c0s cfs];
            new_boxes_to_eval_xcycwh   = [xcs ycs ws hs];
                
            boxes_to_eval_r0rfc0cf = [ boxes_to_eval_r0rfc0cf; new_boxes_to_eval_r0rfc0cf ];
            box_sources_r0rfc0cf   = [ box_sources_r0rfc0cf;   repmat(cur_ob_box_r0rfc0cf,size(new_boxes_to_eval_r0rfc0cf,1),1) ];
            box_source_obj_type    = [ box_source_obj_type;    repmat(oi,size(new_boxes_to_eval_r0rfc0cf,1),1) ];
            
        end
        
        boxes_to_remove = false(size(boxes_to_eval_r0rfc0cf,1),1);
        boxes_to_remove( boxes_to_eval_r0rfc0cf(:,1) >= boxes_to_eval_r0rfc0cf(:,2) ) = true;
        boxes_to_remove( boxes_to_eval_r0rfc0cf(:,3) >= boxes_to_eval_r0rfc0cf(:,4) ) = true;
        boxes_to_remove( boxes_to_eval_r0rfc0cf(:,1) < 1 ) = true;
        boxes_to_remove( boxes_to_eval_r0rfc0cf(:,2) > im_data(imi).im_h ) = true;
        boxes_to_remove( boxes_to_eval_r0rfc0cf(:,3) < 1 ) = true;
        boxes_to_remove( boxes_to_eval_r0rfc0cf(:,4) > im_data(imi).im_w ) = true;
        
        boxes_to_eval_r0rfc0cf(boxes_to_remove,:) = [];
        box_sources_r0rfc0cf(boxes_to_remove,:)   = [];
        box_source_obj_type(boxes_to_remove)      = [];
        
        IOUs_with_source          = nan( size(boxes_to_eval_r0rfc0cf,1), 1 );
        delta_with_source_xywh    = nan( size(boxes_to_eval_r0rfc0cf,1), 4 );
        cnn_features_partial      = nan( size(boxes_to_eval_r0rfc0cf,1), cnn_output_size_partial );
        cnn_features_full         = nan( size(boxes_to_eval_r0rfc0cf,1), cnn_output_size_full );
        classification_confidence = nan( size(boxes_to_eval_r0rfc0cf,1), 1 );
        density_prior             = nan(size(boxes_to_eval_r0rfc0cf,1),1);
        density_conditioned_1a    = nan(size(boxes_to_eval_r0rfc0cf,1),1);
        density_conditioned_1b    = nan(size(boxes_to_eval_r0rfc0cf,1),1);
        density_conditioned_2     = nan(size(boxes_to_eval_r0rfc0cf,1),1);
           
        linear_scaling_factor = sqrt(1 / ( im_data(imi).im_h * im_data(imi).im_w ));
        
        for bi = 1:size(boxes_to_eval_r0rfc0cf,1)
        %for bi = 1:5 
        
            oi = box_source_obj_type(bi);
            cur_obj_type = p.situation_objects{oi};
            conditioning_objects = sort(p.situation_objects( setsub( 1:length(p.situation_objects), oi ) ));
            
        
            if bi == 1 || ~isequal(box_source_obj_type(bi),box_source_obj_type(bi-1))
                
                % if it's the first box, or if the current source object
                % is different from the last time we did this, redefine the
                % dummy workspace that we'll use for conditioning.
            
                workspace_temp_1a = [];
                    workspace_temp_1a.labels = conditioning_objects(1);
                    workspace_temp_1a.boxes_r0rfc0cf = im_data(imi).boxes_normalized_r0rfc0cf( strcmp(conditioning_objects(1),im_data(imi).labels_adjusted), : );
                workspace_temp_1b = [];
                    workspace_temp_1b.labels = conditioning_objects(2);
                    workspace_temp_1b.boxes_r0rfc0cf = im_data(imi).boxes_normalized_r0rfc0cf( strcmp(conditioning_objects(2),im_data(imi).labels_adjusted), : );
                workspace_temp_2  = [];
                    workspace_temp_2.labels = conditioning_objects;
                    workspace_temp_2.boxes_r0rfc0cf = im_data(imi).boxes_normalized_r0rfc0cf( logical(strcmp(conditioning_objects(1),im_data(imi).labels_adjusted) + strcmp(conditioning_objects(2),im_data(imi).labels_adjusted)), : );

                conditioned_model_0  = p.situation_model_update( situation_model, cur_obj_type, [] );
                conditioned_model_1a = p.situation_model_update( situation_model, cur_obj_type, workspace_temp_1a );
                conditioned_model_1b = p.situation_model_update( situation_model, cur_obj_type, workspace_temp_1b );
                conditioned_model_2  = p.situation_model_update( situation_model, cur_obj_type, workspace_temp_2  );

            end
             
            cur_box_r0rfc0cf = boxes_to_eval_r0rfc0cf(bi,:);
            r0 = cur_box_r0rfc0cf(1);
            rf = cur_box_r0rfc0cf(2);
            c0 = cur_box_r0rfc0cf(3);
            cf = cur_box_r0rfc0cf(4);
            cur_w = cf - c0 + 1;
            cur_h = rf - r0 + 1;
            cur_xc = c0 + cur_w/2 - .5;
            cur_yc = r0 + cur_h/2 - .5;
            
            source_box_r0rfc0cf = box_sources_r0rfc0cf(bi,:);
            
            gt_r0 = source_box_r0rfc0cf(1);
            gt_rf = source_box_r0rfc0cf(2);
            gt_c0 = source_box_r0rfc0cf(3);
            gt_cf = source_box_r0rfc0cf(4);
            gt_w  = gt_cf - gt_c0 + 1;
            gt_h  = gt_rf - gt_r0 + 1;
            gt_xc = gt_c0 + gt_w/2 + .5;
            gt_yc = gt_r0 + gt_h/2 + .5;
            
            IOUs_with_source(bi) = intersection_over_union( cur_box_r0rfc0cf, source_box_r0rfc0cf, 'r0rfc0cf');
            delta_with_source_xywh(bi,:) = [ (gt_xc - cur_xc)/cur_w, (gt_yc - cur_yc)/cur_h, gt_w/cur_w, gt_h/cur_h ];
            
            cur_crop = im(r0:rf,c0:cf,:);
            cnn_features_full(bi,:) = cnn.cnn_process( cur_crop );
            [~,classifier_conf] = classifier_model.models{ box_source_obj_type(bi) }.predict( cnn_features_full(bi,:) );
            classification_confidence(bi) = classifier_conf(2);
           
            temp_features = cnn.cnn_process( cur_crop, [], 15 );
            cnn_features_partial(bi,:) = temp_features(:);
            
            r0_normed = linear_scaling_factor * (r0 - im_data(imi).im_h/2);
            rf_normed = linear_scaling_factor * (rf - im_data(imi).im_h/2);
            c0_normed = linear_scaling_factor * (c0 - im_data(imi).im_w/2);
            cf_normed = linear_scaling_factor * (cf - im_data(imi).im_w/2);
            w_normed  = linear_scaling_factor * cur_w;
            h_normed  = linear_scaling_factor * cur_h;
            rc_normed = r0_normed + h_normed/2;
            cc_normed = c0_normed + w_normed/2;
            log_aspect_ratio = log(w_normed / h_normed);
            log_area_ratio = log(w_normed * h_normed);
            
            cur_box_long_vect = [ r0_normed rc_normed rf_normed c0_normed cc_normed cf_normed log(w_normed) log(h_normed) log_aspect_ratio log_area_ratio];
             
            density_prior(bi)          = mvnpdf( cur_box_long_vect, conditioned_model_0.mu,   conditioned_model_0.Sigma  );
            density_conditioned_1a(bi) = mvnpdf( cur_box_long_vect, conditioned_model_1a.mu', conditioned_model_1a.Sigma );
            density_conditioned_1b(bi) = mvnpdf( cur_box_long_vect, conditioned_model_1b.mu', conditioned_model_1b.Sigma );
            density_conditioned_2(bi)  = mvnpdf( cur_box_long_vect, conditioned_model_2.mu',  conditioned_model_2.Sigma  );
            
            fprintf('.');
            
        end
        
        if isempty(data_per_image)
            data_per_image.box_proposals_r0rfc0cf = boxes_to_eval_r0rfc0cf;
            data_per_image.box_sources_r0rfc0cf = box_sources_r0rfc0cf;
            data_per_image.box_sources_obj_type = box_source_obj_type;
            data_per_image.IOUs_with_source = IOUs_with_source;
            data_per_image.delta_with_source_xywh = delta_with_source_xywh;
            data_per_image.cnn_features_partial = cnn_features_partial;
            data_per_image.cnn_features_full = cnn_features_full;
            data_per_image.classification_confidence = classification_confidence;
            data_per_image.density_prior = density_prior;
            data_per_image.density_conditioned_1a = density_conditioned_1a;
            data_per_image.density_conditioned_1b = density_conditioned_1b;
            data_per_image.density_conditioned_2 = density_conditioned_2;
        else
            data_per_image(imi).box_proposals_r0rfc0cf = boxes_to_eval_r0rfc0cf;
            data_per_image(imi).box_sources_r0rfc0cf = box_sources_r0rfc0cf;
            data_per_image(imi).box_sources_obj_type = box_source_obj_type;
            data_per_image(imi).IOUs_with_source = IOUs_with_source;
            data_per_image(imi).delta_with_source_xywh = delta_with_source_xywh;
            data_per_image(imi).cnn_features_partial = cnn_features_partial;
            data_per_image(imi).cnn_features_full = cnn_features_full;
            data_per_image(imi).classification_confidence = classification_confidence;
            data_per_image(imi).density_prior = density_prior;
            data_per_image(imi).density_conditioned_1a = density_conditioned_1a;
            data_per_image(imi).density_conditioned_1b = density_conditioned_1b;
            data_per_image(imi).density_conditioned_2 = density_conditioned_2;
        end
     
        fprintf('\n');
        progress(imi,length(fnames_train),'image progress');
        
    end
    
    save_name = ['pile_of_data_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat' ];
    save( fullfile( '/Users/Max/Desktop/', save_name ) );
    
            
            
    %% some analysis
    
    object_type = [];
    density_prior = [];
    density_conditioned_1a = [];
    density_conditioned_1b = [];
    density_conditioned_2 = [];
    IOU_with_source = [];
    classification_confidence = [];
    
    
    
    for imi = 1:length(data_per_image)
        object_type(end+1:end+length(data_per_image(imi).IOUs_with_source))               = data_per_image(imi).box_sources_obj_type;     
        density_prior(end+1:end+length(data_per_image(imi).IOUs_with_source))             = data_per_image(imi).density_prior;
        density_conditioned_1a(end+1:end+length(data_per_image(imi).IOUs_with_source))    = data_per_image(imi).density_conditioned_1a;
        density_conditioned_1b(end+1:end+length(data_per_image(imi).IOUs_with_source))    = data_per_image(imi).density_conditioned_1b;
        density_conditioned_2(end+1:end+length(data_per_image(imi).IOUs_with_source))     = data_per_image(imi).density_conditioned_2;
        IOU_with_source(end+1:end+length(data_per_image(imi).IOUs_with_source))           = data_per_image(imi).IOUs_with_source;
        classification_confidence(end+1:end+length(data_per_image(imi).IOUs_with_source)) = data_per_image(imi).classification_confidence;
    end
    
    
    
    figure();
    for oi = 1:length(p.situation_objects)
    %for oi = 1
        
        cur_inds = oi == object_type;
        
        subplot2(length(p.situation_objects),6,oi,1);
        hist(log(density_prior(cur_inds)),50);
        if oi == 1, title('density prior'); end
        ylabel( p.situation_objects{oi} );
        
        subplot2(length(p.situation_objects),6,oi,2);
        hist(log(density_conditioned_1a(cur_inds)),50);
        if oi == 1, title('density conditioned 1a'); end
        
        subplot2(length(p.situation_objects),6,oi,3);
        hist(log(density_conditioned_1b(cur_inds)),50);
        if oi == 1, title('density conditioned 1b'); end
        
        subplot2(length(p.situation_objects),6,oi,4);
        hist(log(density_conditioned_2(cur_inds)),50);
        if oi == 1, title('density conditioned 2'); end
        
        subplot2(length(p.situation_objects),6,oi,5);
        hist(classification_confidence(cur_inds),50);
        if oi == 1, title('classifier confidence'); end
        
        subplot2(length(p.situation_objects),6,oi,6);
        hist(IOU_with_source(cur_inds),50);
        if oi == 1, title('IOU'); end
        
    end
    
    
    
    b0  = zeros(0,4);
    b1a = zeros(0,4);
    b1b = zeros(0,4);
    b2  = zeros(0,4);
    b_combined = zeros(0,4);
    
    figure('name','densities with no conditioning');
    for oi = 1:length(p.situation_objects)
    %for oi = 1
        
        cur_inds = oi == object_type;
        
        external_support_vals = logistic( log(density_prior(cur_inds))', .1);
        internal_support_vals = classification_confidence(cur_inds)';
        
        x0 = [external_support_vals  internal_support_vals external_support_vals.*(.01 + internal_support_vals) ]; 
        
        y = IOU_with_source(cur_inds)';
        dist = 'binomial';
        link = 'logit';
        b0(oi,:) = glmfit(x0,y,dist,link);
        y_hat = glmval(b0(oi,:)',x0,link);
        subplot(1,length(p.situation_objects),oi);
        plot(y,y_hat,'.');
        xlabel('iou actual');
        ylabel('iou predicted');
        title(p.situation_objects{oi});
        xlim([0 1]);
        ylim([0 1]);
        
    end
    
    
    
    figure('name','densities conditioned with 1a other object');
    for oi = 1:length(p.situation_objects)
    %for oi = 1
        
        cur_inds = oi == object_type;
       
        external_support_vals = logistic( log(density_conditioned_1a(cur_inds))', .1);
        internal_support_vals = classification_confidence(cur_inds)';
        
        x1a = [external_support_vals  internal_support_vals external_support_vals.*(.01 + internal_support_vals) ]; 
        
        y = IOU_with_source(cur_inds)';
        dist = 'binomial';
        link = 'logit';
        b1a(oi,:) = glmfit(x1a,y,dist,link);
        y_hat = glmval(b1a(oi,:)',x1a,link);
        subplot(1,length(p.situation_objects),oi);
        plot(y,y_hat,'.');
        xlabel('iou actual');
        ylabel('iou predicted');
        title(p.situation_objects{oi});
        xlim([0 1]);
        ylim([0 1]);
        
    end


    
    figure('name','densities conditioned with 1b other object');
    for oi = 1:length(p.situation_objects)
    %for oi = 1
        
        cur_inds = oi == object_type;
       
        external_support_vals = logistic( log(density_conditioned_1b(cur_inds))', .1);
        internal_support_vals = classification_confidence(cur_inds)';
        
        x1b = [external_support_vals  internal_support_vals external_support_vals.*(.01 + internal_support_vals) ]; 
        
        y = IOU_with_source(cur_inds)';
        dist = 'binomial';
        link = 'logit';
        b1b(oi,:) = glmfit(x1b,y,dist,link);
        y_hat = glmval(b1b(oi,:)',x1b,link);
        subplot(1,length(p.situation_objects),oi);
        plot(y,y_hat,'.');
        xlabel('iou actual');
        ylabel('iou predicted');
        title(p.situation_objects{oi});
        xlim([0 1]);
        ylim([0 1]);
        
    end

    
    
    figure('name','densities conditioned with 2 objects');
    for oi = 1:length(p.situation_objects)
    %for oi = 1
        
        cur_inds = oi == object_type;
       
        external_support_vals = logistic( log(density_conditioned_2(cur_inds))', .1);
        internal_support_vals = classification_confidence(cur_inds)';
        
        x2 = [external_support_vals  internal_support_vals external_support_vals.*(.01 + internal_support_vals) ]; 
        
        y = IOU_with_source(cur_inds)';
        dist = 'binomial';
        link = 'logit';
        b2(oi,:) = glmfit(x2,y,dist,link);
        y_hat = glmval(b2(oi,:)',x2,link);
        subplot(1,length(p.situation_objects),oi);
        plot(y,y_hat,'.');
        xlabel('iou actual');
        ylabel('iou predicted');
        title(p.situation_objects{oi});
        xlim([0 1]);
        ylim([0 1]);
        
    end
    
    
    
    figure('name','densities without respect number of conditioning objects');
    for oi = 1:length(p.situation_objects)
    %for oi = 1
        
        cur_inds = oi == object_type;
       
        external_support_vals = logistic( [log(density_prior(cur_inds))'; log(density_conditioned_1a(cur_inds))'; log(density_conditioned_1b(cur_inds))'; log(density_conditioned_2(cur_inds))'], .1);
        internal_support_vals = repmat(classification_confidence(cur_inds)',4,1);
        
        x2 = [external_support_vals  internal_support_vals external_support_vals.*(.01 + internal_support_vals) ]; 
        
        y = repmat(IOU_with_source(cur_inds)',4,1);
        
        dist = 'binomial';
        link = 'logit';
        b_combined(oi,:) = glmfit(x2,y,dist,link);
        y_hat = glmval(b_combined(oi,:)',x2,link);
        subplot(1,length(p.situation_objects),oi);
        plot(y,y_hat,'.');
        xlabel('iou actual');
        ylabel('iou predicted');
        title(p.situation_objects{oi});
        xlim([0 1]);
        ylim([0 1]);
        
    end
    
    
    
    figure()
    for oi = 1:length(p.situation_objects)
        
        cur_inds = oi == object_type;
        densities = [log(density_prior(cur_inds))' log(density_conditioned_1a(cur_inds))' log(density_conditioned_1b(cur_inds))' log(density_conditioned_2(cur_inds))'];
        external_support = logistic( densities(:), .1 );
        
        subplot(1,length(p.situation_objects),oi);
        hist(external_support,50);
        title(p.situation_objects{oi});
        minmax_str = ['min:' num2str(min(external_support)) ' max:' num2str(max(external_support))];
        xlabel(minmax_str);
        
    end





