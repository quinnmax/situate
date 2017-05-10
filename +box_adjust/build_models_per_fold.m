

%% define training images / acceptable crops

  
    p = situate.parameters_initialize();
    p.situation_model.fit          = @situation_models.normal_fit;        
    p.situation_model.update       = @situation_models.normal_condition; 
    p.situation_model.sample       = @situation_models.normal_sample;  
    p.situation_model.draw         = @situation_models.normal_draw;  
    
    p.classifier_load_or_train = @classifiers.cnnsvm_train;
    p.classifier_apply         = @classifiers.cnnsvm_apply;
    p.classifier_saved_models_directory = 'default_models/';
    
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
    assert( ~isempty(fnames_splits_train) );
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

%% train model for each fold
 
saved_models_directory = '/Users/Max/Dropbox/Projects/situate/default_models/';
training_IOU_threshold = .1;
models = cell(1,5);
for feature_ind = 1:length(data_folds)

    fnames_train_no_path = data_folds(feature_ind).fnames_lb_train;
    fnames_train = cellfun( @(x) fullfile( data_path, x ), fnames_train_no_path, 'UniformOutput', false );
    
    models{feature_ind} = box_adjust.train( fnames_train, training_IOU_threshold, saved_models_directory );
end


%% load cnn data for testing

cnn_data = load('/Users/Max/Desktop/cnn_features_and_IOUs2017.04.12.18.16.49.mat');


%% test application to some test images

figure;

for fold_ind = 1:5

   
    % get computed cnn features 
    
    fnames_test = data_folds(fold_ind).fnames_lb_test;
    cnn_data_fnames_pathless = cellfun( @(x) x(last(strfind( x, filesep() ))+1:end), cnn_data.fnames, 'UniformOutput', false );
    fnames_test_inds = ismember( cnn_data_fnames_pathless, fnames_test );
    test_box_row_inds = ismember( cnn_data.fname_source_index, find(fnames_test_inds) );
    
    IOU_results = cell(1,length(models{1}.object_types));
    
    for oi = 1:length(models{1}.object_types)
        
        cur_box_rows = find( test_box_row_inds & eq( cnn_data.box_source_obj_type, oi ) );
        
        cur_obj_IOU_results = zeros( length(cur_box_rows), 2 );
        
        for bi = 1:length(cur_box_rows)

            cur_row = cur_box_rows(bi);

            r0 = cnn_data.box_proposals_r0rfc0cf(cur_row,1);
            rf = cnn_data.box_proposals_r0rfc0cf(cur_row,2);
            c0 = cnn_data.box_proposals_r0rfc0cf(cur_row,3);
            cf = cnn_data.box_proposals_r0rfc0cf(cur_row,4);
            w  = cf - c0 + 1;
            h  = rf - r0 + 1;
            xc = c0 + w/2;
            yc = r0 + h/2;

            % x adjust
            feature_ind = 1;
            x_delta_predicted = [1 cnn_data.box_proposal_cnn_features(cur_row,:)] * models{fold_ind}.weight_vectors{oi,feature_ind};
            xc_hat = xc + w * x_delta_predicted;

            % y adjust
            feature_ind = 2;
            y_delta_predicted = [1 cnn_data.box_proposal_cnn_features(cur_row,:)] * models{fold_ind}.weight_vectors{oi,feature_ind};
            yc_hat = yc + h * y_delta_predicted;

            % w adjust
            feature_ind = 3;
            w_delta_predicted = [1 cnn_data.box_proposal_cnn_features(cur_row,:)] * models{fold_ind}.weight_vectors{oi,feature_ind};
            w_hat = w * exp(w_delta_predicted);

            % h adjust
            feature_ind = 4;
            h_delta_predicted = [1 cnn_data.box_proposal_cnn_features(cur_row,:)] * models{fold_ind}.weight_vectors{oi,feature_ind};
            h_hat = h * exp(h_delta_predicted);

            % updated box
            r0_new = yc_hat - h_hat/2 - .5;
            rf_new = r0_new + h_hat - 1;
            c0_new = xc_hat - w_hat/2 - .5;
            cf_new = c0_new + w_hat - 1;
            box_adjusted_r0rfc0cf = [r0_new rf_new c0_new cf_new];

            % updated IOU
            box_original_IOU = intersection_over_union( cnn_data.box_sources_r0rfc0cf(cur_row,:), [r0 rf c0 cf], 'r0rfc0cf' );
            box_adjusted_IOU = intersection_over_union( cnn_data.box_sources_r0rfc0cf(cur_row,:), box_adjusted_r0rfc0cf, 'r0rfc0cf' );

            cur_obj_IOU_results(bi,:) = [ box_original_IOU, box_adjusted_IOU ];
            
            if mod(bi,100)==0, fprintf('.'); end

        end
        
        IOU_results{oi} = cur_obj_IOU_results;
        
        fprintf('\n');
        
    end
    
    
    for oi = 1:length(p.situation_objects)
        subplot2(5,length(p.situation_objects),fold_ind,oi)
        plot( IOU_results{oi}(:,1), IOU_results{oi}(:,2), '.')
        hold on
        plot( [0 1], [0 1], 'linewidth', 2 );
        hold off;
        xlabel('original IOU');
        ylabel('adjusted IOU');
        title(p.situation_objects{oi})
    end
    
end




    





