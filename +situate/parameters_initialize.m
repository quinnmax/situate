
function p = parameters_initialize()

    % p = situate_parameters_initialize();
    %
    % lots of options outlined in comments

    p = [];
    p.description = 'default parameters';
    p.image_redim_px = 500000;
    p.num_iterations = 1000;
    
     % population settings
        p.num_scouts = 10;
        p.agent_urgency_defaults.scout    = 1;
        p.agent_urgency_defaults.reviewer = 5;
        p.agent_urgency_defaults.builder  = 10;
        
    % pipeline
        p.use_direct_scout_to_workspace_pipe = true; % hides stochastic agent stuff a bit, more comparable to other methods     
        p.stopping_condition = @situate.stopping_condition_finish_up_pool; % stop once the situation is checked-in and residual agents have been evaluated
        
    % situation model
        p.situation_model.learn  = @(a,b) situation_models.uniform_normal_mix_fit(a,b,.5);        
        p.situation_model.update = @situation_models.uniform_normal_mix_condition; 
        p.situation_model.sample = @situation_models.uniform_normal_mix_sample;  
        p.situation_model.draw   = @situation_models.uniform_normal_mix_draw;
        
    % classifier
        p.classifier_load_or_train = @classifiers.IOU_ridge_regression_train;
        p.classifier_apply = @classifiers.IOU_ridge_regression_apply;
        p.classifier_saved_models_directory = 'default_models/';
                   
    % support functions
        activation_function = @(x,b) b(1) + b(2) * atan( b(3) * (x-b(4)) );
        b = [ 0.0237, 0.6106, 4.4710e-12, -0.3192 ];
        p.external_support_function = @(x) activation_function(x,b);
    
        b = [ 0.0441    0.8744    0.0256    0.0068; ...
             -0.0227    0.9646    0.0517    0.0073; ...
              0.0319    0.5971    0.2638    0.0047  ];
        p.total_support_function    = {};
        p.total_support_function{1} = @(internal,external) b(1,1) + b(1,2) * internal + b(1,3) * external + b(1,4) * internal * external;
        p.total_support_function{2} = @(internal,external) b(2,1) + b(2,2) * internal + b(2,3) * external + b(2,4) * internal * external;
        p.total_support_function{3} = @(internal,external) b(3,1) + b(3,2) * internal + b(3,3) * external + b(3,4) * internal * external;
        
    % thresholds
        p.thresholds.internal_support          = .2;    % scout -> reviewer threshold
        p.thresholds.total_support_provisional = inf;   % workspace entry, provisional (search continues)
        p.thresholds.total_support_final       = .5625; % workspace entry, final (search (maybe) ends) depends on p.situation_objects_urgency_post
        
    % adjustment model
        p.adjustment_model_activation_logic = @(cur_agent,a,b) false;
        p.adjustment_model_setup            = @(a,b,c,d) [];
        p.adjustment_model_apply            = @(cur_agent) assert(1==0);
        
    % object urgency 
        p.situation_objects_urgency_pre  = 1.00;
        p.situation_objects_urgency_post = 0.25;
        
    % temperature
        p.temperature = [];
        p.temperature.initial = 100;
        p.temperature.update = @(x) 100; % do nothing, anywhere
        
     % visualization options
        p.viz_options.on_iteration          = false;
        p.viz_options.on_iteration_mod      = 1;
        p.viz_options.on_workspace_change   = false;
        p.viz_options.on_end                = false;
        p.viz_options.start_paused          = false;
    
    end







