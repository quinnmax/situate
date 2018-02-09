
function situations_struct = load_situation_definitions_all(arg)

    % function out = situate_situation_definitions();

    % this looks in the situation definitions directory and tries to match the specified situation with
    % its definition.
    %
    % if no situation is specified, then all of the situations in the directory are returned in a
    % struct array

    situation_definition_directory = 'situation_definitions/';
    dir_data = dir( fullfile( situation_definition_directory, '*.json' ) );
    num_situations = length(dir_data);

    % load situation structs
    situations_struct = [];
    for sfi = 1:num_situations

        cur_fname = fullfile(situation_definition_directory,dir_data(sfi).name);
        cur_situation = situate.situation_struct_load_json( cur_fname );

        if isempty(situations_struct) 
            situations_struct = cur_situation;
            situations_struct = repmat(situations_struct,num_situations,1);
        else
            situations_struct(sfi) = cur_situation; %#ok<AGROW>
        end

    end

    temp = [];
    for i = 1:length(situations_struct)
        temp.(situations_struct(i).desc) = situations_struct(i);
    end
    situations_struct = temp;
    
    if exist('arg','var') && ismember( arg, fieldnames( situations_struct ) )
        situations_struct = situations_struct.(arg);
    end


end

  