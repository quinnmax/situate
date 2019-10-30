function p = parameters_initialize_from_file( params_situate_fname )

% p = parameters_initialize_from_file( params_situate_fname );
% should be a running parameters file (not an experiment parameters file)
% likely from situate/params_run/



    %% parameters from situate param file
    
    d_json = jsondecode_file( params_situate_fname );
    params_in = d_json.situate_parameterization;
    
    p = [];
    p.description = params_situate_fname;
    p.num_iterations = params_in.maximum_iterations;
    
    if isempty( params_in.agent_pool_adjustment_rule )
        p.agent_pool_adjustment_function = [];
    else
        p.agent_pool_adjustment_function = str2func( params_in.agent_pool_adjustment_rule );
    end
    
    p.agent_pool_initialization_function = str2func( params_in.agent_pool_initialization_function );
    
    p.num_scouts = params_in.min_number_of_scouts;
    p.agent_urgency_defaults.scout    = params_in.agent_urgency_defaults.scout;
    p.agent_urgency_defaults.reviewer = params_in.agent_urgency_defaults.reviewer;
    p.agent_urgency_defaults.builder  = params_in.agent_urgency_defaults.builder;

    if strcmp( params_in.use_direct_scout_to_workspace_pipeline, 'true' )
        p.use_direct_scout_to_workspace_pipe = true;
    else
        p.use_direct_scout_to_workspace_pipe = false;
    end
        
    p.stopping_condition = str2func( params_in.stopping_condition );
    
    p.situation_model = [];
        p.situation_model.description = params_in.situation_model;
        p.situation_model.learn  = str2func([ params_in.situation_model.learn  ]);
        p.situation_model.update = str2func([ params_in.situation_model.update ]);
        p.situation_model.sample = str2func([ params_in.situation_model.sample ]);
        p.situation_model.draw   = str2func([ params_in.situation_model.draw   ]);
        
    p.classifier = [];
        p.classifier.description = params_in.classifier;
        p.classifier.train = str2func(params_in.classifier.train);
        p.classifier.apply = str2func(params_in.classifier.apply);
        p.classifier.directory = params_in.classifier.store;
    
    p.external_support_function_description = params_in.support_function_external;
    p.external_support_function = str2func( params_in.support_function_external );
    
    p.total_support_function_description = params_in.support_function_total;
    p.total_support_function = str2func( params_in.support_function_total );
    
    p.situation_grounding_function_description = params_in.support_function_full_situation;
    p.situation_grounding_function = str2func( params_in.support_function_full_situation );
    
    p.thresholds = [];
        p.thresholds.internal_support          = str2double( params_in.support_thresholds.internal_support );
        p.thresholds.internal_support_retain   = str2double( params_in.support_thresholds.internal_support_retain );
        p.thresholds.total_support_provisional = str2double( params_in.support_thresholds.total_support_provisional );
        p.thresholds.total_support_final       = str2double( params_in.support_thresholds.total_support_final );
    
    p.adjustment_model = [];
        p.adjustment_model.description      = params_in.agent_adjustment_model;
        p.adjustment_model.train            = str2func( params_in.agent_adjustment_model.train );
        p.adjustment_model.activation_logic = str2func( params_in.agent_adjustment_model.activation_logic );
        p.adjustment_model.apply            = str2func( params_in.agent_adjustment_model.apply );
        p.adjustment_model.directory        = params_in.agent_adjustment_model.store;     
        
    p.temperature = [];
        p.temperature.initial = params_in.temperature.initial;
        p.temperature.update = str2func( params_in.temperature.update_rule );
    
    if isfield(params_in,'use_monte')
        p.use_monte =  params_in.use_monte;
    else
        p.use_monte =  false;
    end
    
    %% parameters from situation definition
    
    p.situation_description = '';
    p.situation_objects = {};
    p.situation_objects_possible_labels = {{}};
    p.situation_objects_urgency_pre  = [];
    p.situation_objects_urgency_post = [];
    
    
    
    %% parameters from experiment script
    
    p.seed_test      = [];
    p.use_visualizer = [];
    p.viz_options    = [];
    p.use_parallel   = [];
    
        
    
end
    
    
    
    



