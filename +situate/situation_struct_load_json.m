  function cur_situation = situation_struct_load_json( fname )
  
    % cur_situation = situation_struct_load_json( fname );

        situation_data_temp = jsondecode(fileread(fname));
        % situation name
        cur_situation.desc = situation_data_temp.situation.description;
        % situation objects
        cur_situation.situation_objects = fieldnames(situation_data_temp.situation.situation_objects)';
        num_objects = length( cur_situation.situation_objects );
        % possible labels
        situation_objects_possible_labels = cell(1,num_objects);
        % object urgency pre/post
        object_urgency_pre  = zeros( 1, num_objects );
        object_urgency_post = zeros( 1, num_objects );
        for oi = 1:num_objects
            cur_obj = cur_situation.situation_objects{oi};
            situation_objects_possible_labels{oi} = situation_data_temp.situation.situation_objects.(cur_obj).possible_labels;
            object_urgency_pre(oi)                = str2double(situation_data_temp.situation.situation_objects.(cur_obj).urgency_pre);
            object_urgency_post(oi)               = str2double(situation_data_temp.situation.situation_objects.(cur_obj).urgency_post);
        end
        cur_situation.situation_objects_possible_labels = situation_objects_possible_labels;
        cur_situation.object_urgency_pre   = object_urgency_pre;
        cur_situation.object_urgency_post  = object_urgency_post;
        cur_situation.possible_paths_train = situation_data_temp.situation.possible_training_data_paths;
        cur_situation.possible_paths_test  = cur_situation.possible_paths_train;
        
  end