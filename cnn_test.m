% classifier test

%% set up

% set training and testing splits
split_file_directory = '/Users/Max/Dropbox/Projects/situate/default_split';
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

% set up situate parameters and set up situation
p = situate.parameters_initialize();

p.image_redim_px = 500000;

situation_options = situate.situation_definitions;
situation = situation_options.('dogwalking');
p.situation_objects = situation.situation_objects;
p.situation_objects_possible_labels = situation.situation_objects_possible_labels;
path_ind = find( cellfun(@isdir, situation.possible_paths), 1, 'first' );
path = situation.possible_paths{path_ind};

fnames_train = cellfun( @(x) fullfile( path, x ), data_folds.fnames_lb_train, 'UniformOutput', false );
fnames_test  = cellfun( @(x) fullfile( path, x ), data_folds.fnames_lb_test, 'UniformOutput', false );

p.situation_model_learn  = @situation_model_normal_fit;
p.situation_model_sample = @situation_model_normal_aa_sample;
p.situation_model_update = @situation_model_normal_condition;

% build the prior based on the trainingdata path
situation_model_prior = p.situation_model_learn( p, fnames_train );

% load the cnnsvm model
model_directory_possible_paths = {'/Users/Max/Dropbox/Projects/situate/default_models'};
selected_model_fname = situate.check_for_existing_model( model_directory_possible_paths, fnames_train );
classifier_model = load( selected_model_fname );

%% eval on testing images

classifier_scores = zeros( length(fnames_test), length(p.situation_objects), length(p.situation_objects) ); 
for fi = 1:length( fnames_test )
    use_resize = true;
    [im_data,im] = situate.load_image_and_data( fnames_test{fi}, p, use_resize );
    
    for oi = 1:length(p.situation_objects) % the object to pull out
        cur_obj = p.situation_objects{oi};
        bi = find( strcmp( im_data.labels_adjusted, cur_obj ) );
        r0 = im_data.boxes_r0rfc0cf(bi,1);
        rf = im_data.boxes_r0rfc0cf(bi,2);
        c0 = im_data.boxes_r0rfc0cf(bi,3);
        cf = im_data.boxes_r0rfc0cf(bi,4);
        
        r0 = round(r0); rf = round(rf); c0 = round(c0); cf = round(cf);
        r0 = max(r0,1);
        rf = min(rf,size(im,1));
        c0 = max(c0,1);
        cf = min(cf,size(im,2));
        
        x = c0;
        y = r0;
        w = cf-c0+1;
        h = rf-r0+1;
        
        cur_crop = im(r0:rf,c0:cf,:);
        crop_cnn_features = cnn.cnn_process(floor(256*cur_crop));
        
        for oj = 1:length(p.situation_objects) % the classifier to apply
            
            [~,scores] = classifier_model.models{oj}.predict( crop_cnn_features' ); 
            classifier_scores( fi, oi, oj ) = scores(2);
            
%             d = [];
%             d(oi).learned_stuff.cnn_svm_models.models{oi,1} = classifier_model.models{oi};
%             classifier_scores( fi, oi, oj ) = cnn.score_subimage( im, [x y w h], oi, d, p );
            
        end
    end
    progress(fi,length(fnames_test));
end

figure
for oi = 1:3
    for oj = 1:3
      subplot2(3,3,oi,oj);
      hist( classifier_scores(:,oi,oj),20);
    end
end
            


    
    
        
        
        
    
    
    
    
    
    