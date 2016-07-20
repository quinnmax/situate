


%% put crops into a directory

% from some of the PortlandSimpleDogWalking data

directory = 'C:\Users\Rory\Dropbox\DogWalkingData\PortlandSimpleDogWalking';
parameters_struct = [];
mkdir('C:\Users\Rory\situate_temp');
output_directory = 'C:\Users\Rory\situate_temp';

[output_directory1,fnames1,source_fnames1] = situate_crop_extractor( directory, 'dog', parameters_struct, output_directory );
[output_directory2,fnames2,source_fnames2] = situate_crop_extractor( directory, {'dog-walker','pedestrian'}, parameters_struct, output_directory );
[output_directory3,fnames3,source_fnames3] = situate_crop_extractor( directory, 'leash', parameters_struct, output_directory );
source_fnames1( cellfun(@isempty,source_fnames1) ) = []; 
source_fnames2( cellfun(@isempty,source_fnames2) ) = []; 
source_fnames3( cellfun(@isempty,source_fnames3) ) = []; 
fnames1( cellfun(@isempty,fnames1) ) = [];
fnames2( cellfun(@isempty,fnames2) ) = [];
fnames3( cellfun(@isempty,fnames3) ) = [];

source_fnames1 = unique(source_fnames1);
source_fnames2 = unique(source_fnames2);
source_fnames3 = unique(source_fnames3);



%% train a model

hog_svm_model_parameters_struct = [];
hog_svm_model_parameters_struct.im_resize_px   = 1024;
hog_svm_model_parameters_struct.shape_clusters = 3;

% gather file names for each object type
% split into training and testing sets
training_ratio = .9;

% dog
directory_dog = '/Users/Max/Desktop/situate_hog_svm_training_crops/dog/';
fnames_targets     = image_list([directory_dog 'targets/']);
fnames_distractors = image_list([directory_dog 'distractors/']);
fnames = [fnames_targets fnames_distractors];
labels = [true(length(fnames_targets),1); false(length(fnames_distractors),1)];
p = randperm(length(fnames));
inds_train = p( 1 : round(training_ratio*end) );
inds_test  = setdiff( p, inds_train );
fnames_dog_train = fnames(inds_train);
labels_dog_train = labels(inds_train);
fnames_dog_test  = fnames(inds_test); 
labels_dog_test  = labels(inds_test);

% person
directory_person = '/Users/Max/Desktop/situate_hog_svm_training_crops/dog-walker/';
fnames_targets     = image_list([directory_person 'targets/']);
fnames_distractors = image_list([directory_person 'distractors/']);
fnames = [fnames_targets fnames_distractors];
labels = [true(length(fnames_targets),1); false(length(fnames_distractors),1)];
p = randperm(length(fnames));
inds_train = p( 1 : round(training_ratio*end) );
inds_test  = setdiff( p, inds_train );
fnames_person_train = fnames(inds_train);
labels_person_train = labels(inds_train);
fnames_person_test  = fnames(inds_test); 
labels_person_test  = labels(inds_test);

% leash
directory_leash = '/Users/Max/Desktop/situate_hog_svm_training_crops/leash/';
fnames_targets      = image_list( [directory_leash 'targets/'] );
fnames_distractors  = image_list( [directory_leash 'distractors/'] );
fnames = [fnames_targets fnames_distractors];
labels = [true(length(fnames_targets),1); false(length(fnames_distractors),1)];
p = randperm(length(fnames));
inds_train = p( 1 : round(training_ratio*end) );
inds_test  = setdiff( p, inds_train );
fnames_leash_train = fnames(inds_train);
labels_leash_train = labels(inds_train);
fnames_leash_test  = fnames(inds_test); 
labels_leash_test  = labels(inds_test);

% train the models

hog_svm_model    = hog_svm_model_train( fnames_dog_train,    labels_dog_train,    hog_svm_model_parameters_struct );
hog_svm_model(2) = hog_svm_model_train( fnames_person_train, labels_person_train, hog_svm_model_parameters_struct );
hog_svm_model(3) = hog_svm_model_train( fnames_leash_train,  labels_leash_train,  hog_svm_model_parameters_struct );

% ammend with target labels, add record of training fnames
% (not available to the hog_svm_mode_train function, as the source images
% and criteria for making the crops isn't known to it

% ignore the path
temp1 = load([directory_dog    'source_fnames.mat']);
temp1 = cellfun( @(x) split(x,'/'), temp1.source_fnames, 'UniformOutput',false);
temp1 = cellfun( @(x) x{end}, temp1, 'UniformOutput',false);
temp2 = load([directory_person 'source_fnames.mat']);
temp2 = cellfun( @(x) split(x,'/'), temp2.source_fnames, 'UniformOutput',false);
temp2 = cellfun( @(x) x{end}, temp2, 'UniformOutput',false);
temp3 = load([directory_leash  'source_fnames.mat']);
temp3 = cellfun( @(x) split(x,'/'), temp3.source_fnames, 'UniformOutput',false);
temp3 = cellfun( @(x) x{end}, temp3, 'UniformOutput',false);

hog_svm_model(1).training_crop_source_list = temp1;
hog_svm_model(2).training_crop_source_list = temp2;
hog_svm_model(3).training_crop_source_list = temp3;

hog_svm_model(1).target_label = 'dog';
hog_svm_model(2).target_label = 'person';
hog_svm_model(3).target_label = 'leash';



%% save off the model

save('hog_svm_model_saved.mat', 'hog_svm_model');


%% apply the models to the training data

[~, dvars_dog] = hog_svm_model_apply( fnames_dog_train, hog_svm_model(1) );
[ AUROC, TPR, FPR ] = ROC( dvars_dog, labels_dog_train );
roc_training_dog.AUROC = AUROC;
roc_training_dog.TPR = TPR;
roc_training_dog.FPR = FPR;

[~, dvars_person] = hog_svm_model_apply( fnames_person_train, hog_svm_model(2) );
[ AUROC, TPR, FPR ] = ROC( dvars_person, labels_person_train );
roc_training_person.AUROC = AUROC;
roc_training_person.TPR = TPR;
roc_training_person.FPR = FPR;

[~, dvars_leash] = hog_svm_model_apply( fnames_leash_train, hog_svm_model(3) );
[ AUROC, TPR, FPR ] = ROC( dvars_leash, labels_leash_train );
roc_training_leash.AUROC = AUROC;
roc_training_leash.TPR = TPR;
roc_training_leash.FPR = FPR;

%% apply the models to some testing data

[~, dvars_dog] = hog_svm_model_apply( fnames_dog_test, hog_svm_model(1) );
[ AUROC, TPR, FPR ] = ROC( dvars_dog, labels_dog_test );
roc_test_dog.AUROC = AUROC;
roc_test_dog.TPR = TPR;
roc_test_dog.FPR = FPR;

[~, dvars_person] = hog_svm_model_apply( fnames_person_test, hog_svm_model(2) );
[ AUROC, TPR, FPR ] = ROC( dvars_person, labels_person_test );
roc_test_person.AUROC = AUROC;
roc_test_person.TPR = TPR;
roc_test_person.FPR = FPR;

[~, dvars_leash] = hog_svm_model_apply( fnames_leash_test, hog_svm_model(3) );
[ AUROC, TPR, FPR ] = ROC( dvars_leash, labels_leash_test );
roc_test_leash.AUROC = AUROC;
roc_test_leash.TPR = TPR;
roc_test_leash.FPR = FPR;

%% apply the model to mixed testing data, including entries from the other classes
fnames_target       = fnames_dog_test(labels_dog_test);
fnames_distractors  = fnames_person_test;
temp_inds = randperm( length(fnames_distractors) );
temp_inds = temp_inds( 1:length(fnames_target) );
fnames_distractors = fnames_distractors( temp_inds );
fnames = [fnames_target fnames_distractors];
labels = [true( length(fnames_target),1); false(length(fnames_distractors),1)];
[~, dvars] = hog_svm_model_apply( fnames, hog_svm_model(1) );
[ AUROC_dog_person, TPR, FPR ] = ROC( dvars, labels );

fnames_target       = fnames_person_test(labels_person_test);
fnames_distractors  = fnames_dog_test;
temp_inds = randperm( length(fnames_distractors) );
temp_inds = temp_inds( 1:length(fnames_target) );
fnames_distractors = fnames_distractors( temp_inds );
fnames = [fnames_target fnames_distractors];
labels = [true( length(fnames_target),1); false(length(fnames_distractors),1)];
[~, dvars] = hog_svm_model_apply( fnames, hog_svm_model(2) );
[ AUROC_person_dog, TPR, FPR ] = ROC( dvars, labels );

%% spit out results

display( hog_svm_model_parameters_struct );

display(roc_training_dog);
display(roc_training_person);
display(roc_training_leash);

display(roc_test_dog);
display(roc_test_person);
display(roc_test_leash);

display(AUROC_dog_person)
display(AUROC_person_dog)






