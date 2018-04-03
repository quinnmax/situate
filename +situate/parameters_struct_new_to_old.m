function params_struct_out = parameters_struct_new_to_old( experiment_struct, situation_struct, situate_params_array )
    
    
    if isstruct(situate_params_array) && length(situate_params_array) > 1

        params_struct_out = situate_params_array;
        for pi = 1:length( situate_params_array )
            params_struct_out(pi) = situate.parameters_struct_new_to_old( experiment_struct, situation_struct, situate_params_array(pi) );
        end
        
    else
        
        params_struct_out = situate_params_array;
        
        params_struct_out.situation_description = situation_struct.desc;
        
        params_struct_out.situation_description             = situation_struct.desc;
        params_struct_out.situation_objects                 = situation_struct.situation_objects;
        params_struct_out.situation_objects_possible_labels = situation_struct.situation_objects_possible_labels;
        params_struct_out.situation_objects_urgency_pre     = situation_struct.object_urgency_pre;
        params_struct_out.situation_objects_urgency_post    = situation_struct.object_urgency_post;

        if isempty( experiment_struct.experiment_settings.testing_seed )
            params_struct_out.seed_test = [];
        else
            params_struct_out.seed_test = experiment_struct.experiment_settings.testing_seed;
        end

        params_struct_out.use_parallel   = experiment_struct.experiment_settings.use_parallel;
        params_struct_out.use_visualizer = experiment_struct.experiment_settings.use_visualizer;
        params_struct_out.viz_options    = experiment_struct.experiment_settings.viz_options;
        
    end
    
end
