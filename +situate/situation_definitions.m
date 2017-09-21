
function situations_struct = situation_definitions(arg)

% function out = situate_situation_definitions();

% these are the situations that situate deals with so far. they
% have a collection of objects that need to be found to call the detection
% complete, and, for each of those objects, a list of labels found in the
% data that should be mapped to that object type. possible paths specifies
% the directory with images of that situation that will be used in the run

    cur_situation = [];
    situations_struct = [];

    desc = 'dogwalking';
    cur_situation.desc = desc;
    cur_situation.situation_objects =  { 'dogwalker', 'dog', 'leash' };
    object_urgency_pre  = [1 1 1];
    object_urgency_post = [.25 .25 .25];
    for i = 1:length(cur_situation.situation_objects ), cur_situation.object_urgency_pre.( cur_situation.situation_objects{i}) = object_urgency_pre(i);  end
    for i = 1:length(cur_situation.situation_objects ), cur_situation.object_urgency_post.(cur_situation.situation_objects{i}) = object_urgency_post(i); end
    cur_situation.situation_objects_possible_labels = {...
        {'dog-walker back', 'dog-walker front', 'dog-walker my-left', 'dog-walker my-right'},...
        {'dog back', 'dog front', 'dog my-left', 'dog my-right'},...
        {'leash-/', 'leash-\'}};
    cur_situation.possible_paths_train = { ...
        '/Users/mm/Desktop/PortlandSimpleDogWalking/', ...
        '/stash/mm-group/evan/crop_learn/data/PortlandSimpleDogWalking/', ...
        '/Users/Max/Documents/MATLAB/data/situate_images/PortlandSimpleDogWalking/', ...
        '/home/rsoiffer/Desktop/Matlab/DogWalkingData/PortlandSimpleDogWalking/',...
        '/home/maxq/Documents/MATLAB/data/PortlandSimpleDogWalking/'};
    cur_situation.possible_paths_test = cur_situation.possible_paths_train;
    situations_struct.(desc) = cur_situation;
    
    desc = 'dogwalking_holding';
    cur_situation.desc = desc;
    cur_situation.situation_objects =  { 'dogwalker', 'dog', 'leash', 'holding', 'attached' };
    object_urgency_pre  = [1  1 .5 .1 .1];
    object_urgency_post = [0  0  0  0  0];
    for i = 1:length(cur_situation.situation_objects ), cur_situation.object_urgency_pre.( cur_situation.situation_objects{i}) = object_urgency_pre(i);  end
    for i = 1:length(cur_situation.situation_objects ), cur_situation.object_urgency_post.(cur_situation.situation_objects{i}) = object_urgency_post(i); end
    cur_situation.situation_objects_possible_labels = {...
        {'dog-walker back', 'dog-walker front', 'dog-walker my-left', 'dog-walker my-right'},...
        {'dog back', 'dog front', 'dog my-left', 'dog my-right'},...
        {'leash-/', 'leash-\'},...
        {''}, ...
        {''}};
    cur_situation.possible_paths_train = { ...
        '/Users/mm/Desktop/PortlandSimpleDogWalking/', ...
        '/stash/mm-group/evan/crop_learn/data/PortlandSimpleDogWalking/', ...
        '/Users/Max/Documents/MATLAB/data/situate_images/PortlandSimpleDogWalking/', ...
        '/home/rsoiffer/Desktop/Matlab/DogWalkingData/PortlandSimpleDogWalking/'};
    cur_situation.possible_paths_test = cur_situation.possible_paths_train;
    situations_struct.(desc) = cur_situation;
    
    desc = 'dogwalking_no_leash';
    cur_situation.desc = desc;
    cur_situation.situation_objects =  { 'dogwalker', 'dog' };
    object_urgency_pre  = [1 1];
    object_urgency_post = [0 0];
    for i = 1:length(cur_situation.situation_objects ), cur_situation.object_urgency_pre.( cur_situation.situation_objects{i}) = object_urgency_pre(i);  end
    for i = 1:length(cur_situation.situation_objects ), cur_situation.object_urgency_post.(cur_situation.situation_objects{i}) = object_urgency_post(i); end
    cur_situation.situation_objects_possible_labels = {...
        {'dog-walker back', 'dog-walker front', 'dog-walker my-left', 'dog-walker my-right'},...
        {'dog back', 'dog front', 'dog my-left', 'dog my-right'}};
    cur_situation.possible_paths_train = { ...
        '/Users/mm/Desktop/PortlandSimpleDogWalking/', ...
        '/stash/mm-group/evan/crop_learn/data/PortlandSimpleDogWalking/', ...
        '/Users/Max/Documents/MATLAB/data/situate_images/PortlandSimpleDogWalking/', ...
        '/home/rsoiffer/Desktop/Matlab/DogWalkingData/PortlandSimpleDogWalking/'};
    cur_situation.possible_paths_test = cur_situation.possible_paths_train;
    situations_struct.(desc) = cur_situation;
        
    desc = 'handshaking_unsided';
    cur_situation.desc = desc;
    cur_situation.situation_objects = { 'participant1', 'handshake', 'participant2' };
    object_urgency_pre  = [1 1 1];
    object_urgency_post = [.25 .25 .25];
    for i = 1:length(cur_situation.situation_objects ), cur_situation.object_urgency_pre.( cur_situation.situation_objects{i}) = object_urgency_pre(i);  end
    for i = 1:length(cur_situation.situation_objects ), cur_situation.object_urgency_post.(cur_situation.situation_objects{i}) = object_urgency_post(i); end
    cur_situation.situation_objects_possible_labels = {...
        {'person-my-left','person-my-right'}, ...
        {'handshake'}, ...
        {'person-my-left','person-my-right'}};
    cur_situation.possible_paths_train = { ...
        '/Users/Max/Documents/MATLAB/data/situate_images/HandshakeLabeled/train/' };
    cur_situation.possible_paths_test = cur_situation.possible_paths_train;
    situations_struct.(desc) = cur_situation;
    
    desc = 'handshaking';
    cur_situation.desc = desc;
    cur_situation.situation_objects = { 'left', 'handshake', 'right' };
    object_urgency_pre  = [1 1 1];
    object_urgency_post = [.25 .25 .25];
    for i = 1:length(cur_situation.situation_objects ), cur_situation.object_urgency_pre.( cur_situation.situation_objects{i}) = object_urgency_pre(i);  end
    for i = 1:length(cur_situation.situation_objects ), cur_situation.object_urgency_post.(cur_situation.situation_objects{i}) = object_urgency_post(i); end
    cur_situation.situation_objects_possible_labels = {...
        {'person-my-left'}, ...
        {'handshake'}, ...
        {'person-my-right'}};
    cur_situation.possible_paths_train = { ...
        '/Users/Max/Documents/MATLAB/data/situate_images/HandshakeLabeled/train/' };
    cur_situation.possible_paths_test = cur_situation.possible_paths_train;
    situations_struct.(desc) = cur_situation;
    
    desc = 'pingpong';
    cur_situation.desc = desc;
    cur_situation.situation_objects =  { 'table','net','player1','player2' };
    object_urgency_pre  = [1 1 1 1];
    object_urgency_post = [.25 .25 .25 .25];
    for i = 1:length(cur_situation.situation_objects ), cur_situation.object_urgency_pre.( cur_situation.situation_objects{i}) = object_urgency_pre(i);  end
    for i = 1:length(cur_situation.situation_objects ), cur_situation.object_urgency_post.(cur_situation.situation_objects{i}) = object_urgency_post(i); end
    cur_situation.situation_objects_possible_labels = {...
        {'table'}, ...
        {'net'}, ...
        {'player-front','player-back','player-my-left','player-my-right'}, ...
        {'player-front','player-back','player-my-left','player-my-right'}};
    cur_situation.possible_paths_train = { ...
        '/Users/Max/Documents/MATLAB/data/situate_images/PingPongLabeled/Labels/train/'};
    cur_situation.possible_paths_test = cur_situation.possible_paths_train;
    situations_struct.(desc) = cur_situation;
    
    if exist('arg','var') && ismember( arg, fieldnames(situations_struct) )
        situations_struct = situations_struct.(arg);
    end
    
end
    
