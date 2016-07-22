
function situations_struct = situate_situation_definitions()

% function out = situate_situation_definitions();

% these are the situations that situate deals with so far. they
% have a collection of objects that need to be found to call the detection
% complete, and, for each of those objects, a list of labels found in the
% data that should be mapped to that object type. possible paths specifies
% the directory with images of that situation that will be used in the run


    cur_situation = [];
    situations_struct = [];

    desc = 'dogwalking';
    cur_situation.situation_objects =  { 'dogwalker', 'dog', 'leash' };
    cur_situation.situation_objects_possible_labels = {...
        {'dog-walker back', 'dog-walker front', 'dog-walker my-left', 'dog-walker my-right'},...
        {'dog back', 'dog front', 'dog my-left', 'dog my-right'},...
        {'leash-/', 'leash-\'}};
    cur_situation.possible_paths = { ...
        '/Users/mm/Desktop/PortlandSimpleDogWalking/', ...
        '/stash/mm-group/evan/crop_learn/data/PortlandSimpleDogWalking/', ...
        '/Users/Max/Documents/MATLAB/data/situate_images/PortlandSimpleDogWalking/', ...
        '/home/rsoiffer/Desktop/Matlab/DogWalkingData/PortlandSimpleDogWalking/'};
    cur_situation.data_path = cur_situation.possible_paths{ find(cellfun(@(x) exist(x,'dir'), cur_situation.possible_paths ), 1 )};
    situations_struct.(desc) = cur_situation;
    
    desc = 'dogwalking_no_leash';
    cur_situation.situation_objects =  { 'dogwalker', 'dog' };
    cur_situation.situation_objects_possible_labels = {...
        {'dog-walker back', 'dog-walker front', 'dog-walker my-left', 'dog-walker my-right'},...
        {'dog back', 'dog front', 'dog my-left', 'dog my-right'}};
    cur_situation.possible_paths = { ...
        '/Users/mm/Desktop/PortlandSimpleDogWalking/', ...
        '/stash/mm-group/evan/crop_learn/data/PortlandSimpleDogWalking/', ...
        '/Users/Max/Documents/MATLAB/data/situate_images/PortlandSimpleDogWalking/', ...
        '/home/rsoiffer/Desktop/Matlab/DogWalkingData/PortlandSimpleDogWalking/'};
    cur_situation.data_path = cur_situation.possible_paths{ find(cellfun(@(x) exist(x,'dir'), cur_situation.possible_paths ), 1 )};
    situations_struct.(desc) = cur_situation;
        
    desc = 'handshaking';
    cur_situation.situation_objects = { 'person_my_left', 'handshake', 'person_my_right' };
    cur_situation.situation_objects_possible_labels = {...
        {'person-my-left'}, ...
        {'handshake'}, ...
        {'person-my-right'}};
    cur_situation.possible_paths = { ...
        '/Users/Max/Documents/MATLAB/data/situate_images/HandshakeLabeled/', ...
        'C:\Users\LiFamily\Desktop\2016 ASE\HandshakeLabeled',...
        '/fakepath/justchecking'};
    cur_situation.data_path = cur_situation.possible_paths{ find(cellfun(@(x) exist(x,'dir'), cur_situation.possible_paths ), 1 )};
    situations_struct.(desc) = cur_situation;
    
    desc = 'pingpong';
    cur_situation.situation_objects =  { 'table','net','player1','player2' };
    cur_situation.situation_objects_possible_labels = {...
        {'table'}, ...
        {'net'}, ...
        {'player-front','player-back','player-my-left','player-my-right'}, ...
        {'player-front','player-back','player-my-left','player-my-right'}};
    cur_situation.possible_paths = { ...
        '/Users/Max/Documents/MATLAB/data/situate_images/PingPongLabeled/Labels/', ...
        'C:\Users\LiFamily\Desktop\2016 ASE\PingPongLabeled'};
    cur_situation.data_path = cur_situation.possible_paths{ find(cellfun(@(x) exist(x,'dir'), cur_situation.possible_paths ), 1 )};
    situations_struct.(desc) = cur_situation;
    
    
end
    
