
function p = parameters_initialize_default()

    % p = situate_parameters_initialize();
    %
    % lots of options outlined in comments

    p = situate.parameters_initialize_from_file( 'parameterization_situate_default.json' );
      
     % visualization options
        p.viz_options = [];
        p.viz_options.on_iteration          = false;
        p.viz_options.on_iteration_mod      = 1;
        p.viz_options.on_workspace_change   = false;
        p.viz_options.on_end                = false;
        p.viz_options.start_paused          = false;
        
    p.situation_objects                 = {};
    p.situation_objects_possible_labels = {{},{}};
    
end







