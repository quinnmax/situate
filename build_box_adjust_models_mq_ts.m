

% set up
p = situate_parameters_initialize;
p.situation_objects =  { 'dogwalker', 'dog', 'leash' };
p.situation_objects_possible_labels = {...
    {'dog-walker back', 'dog-walker front', 'dog-walker my-left', 'dog-walker my-right'},...
    {'dog back', 'dog front', 'dog my-left', 'dog my-right'},...
    {'leash-/', 'leash-\'}};
possible_paths = { ...
    '/Users/mm/Desktop/PortlandSimpleDogWalking/', ...
    '/Users/Max/Documents/MATLAB/data/situate_images/PortlandSimpleDogWalking/', ...
    '/home/rsoiffer/Desktop/Matlab/DogWalkingData/PortlandSimpleDogWalking/'};
data_path = possible_paths{ find(cellfun(@(x) exist(x,'dir'),possible_paths), 1 )};

% label files
label_files = dir([ data_path '*.labl']);
fnames_lb = cellfun( @(x) [data_path '/' x], {label_files.name}, 'UniformOutput', false );

fnames_lb_train = fnames_lb(1:10);

% models = box_adjust.build_box_adjust_models_mq( fnames_lb_temp, p );













