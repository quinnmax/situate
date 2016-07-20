


situation = 'handshaking';
%situation = 'dogwalking';

num_images = 20;
num_negatives_per_image = 5;


switch situation
    case 'dogwalking'
        label_dir = '/Users/Max/Dropbox/DogWalkingData/PortlandSimpleDogWalking/';
        target_label = 'dog';
        p = situate_parameters_initialize;
        p.situation_objects = { ...
            'dogwalker', ...
            'dog', ...
            'leash' };
        p.situation_objects_possible_labels = {...
            {'dog-walker back', 'dog-walker front', 'dog-walker my-left', 'dog-walker my-right'},...
            {'dog back', 'dog front', 'dog my-left', 'dog my-right'},...
            {'leash-/', 'leash-\'}};

    case 'handshaking'
        label_dir = '/Users/Max/Dropbox/HandshakeLabeled/';

        target_label = 'person-my-left';
        p = situate_parameters_initialize;
        p.situation_objects = { ...
            'person-my-left', ...
            'handshake', ...
            'person-my-right' };
        p.situation_objects_possible_labels = {...
            {'person-my-left'},...
            {'handshake'},...
            {'person-my-rigth'}};
end

temp = dir([label_dir '*.labl']);
fnames_lb = {temp.name};
fnames_lb = cellfun( @(x) [label_dir x], fnames_lb, 'UniformOutput', false );
fnames_lb = fnames_lb(1:100);

[crops_target, crops_negative] = situate_crop_extractor( fnames_lb, target_label, p, num_negatives_per_image );

















