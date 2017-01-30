
function p = parameters_initialize()

    % p = situate_parameters_initialize();
    %
    % lots of options outlined in comments

    p = [];
    
    p.description = '';
    
    p.image_redim_px = 250000;
    
    % center it at the uniform prior value for the size of the empirical
    % distribution that we're using (i.e. we're using 250000 pixels, so
    % each has a value of 1/250000, so make that the center of the external
    % support activation function).
    p.external_support_function = @(x) sigmoid(   2 * p.image_redim_px * ( x - (1/p.image_redim_px) )     );
    %x = linspace(0, 10 * 1/p.image_redim_px, 100);
    %figure(); plot(x,p.external_support_function(x));
    p.total_support_function = @(internal,external) .75 * internal + .25 * external;
        
    % temperature settings
    
        p.use_temperature = true;
    
        p.temperature.initial_value = 100;
        
        % p of using the conditional distribution, rather than the prior
        min = -2;
        max =  5;
        p.temperature.distribution_p_function = @(x) sigmoid( (max - min) * ( 1 - (x/p.temperature.initial_value) ) + min );
%         x = linspace(0,100,100);
%         figure(); plot(x, p.temperature.distribution_p_function(x) );
        
        % p of stopping on any given round
        min = -25;
        max =   0;
        p.temperature.stopping_probability_function = @(x) sigmoid( (max - min) * (1-(x/p.temperature.initial_value)) + min );
%         x = linspace(0,100,100);
%         figure(); plot(x, p.temperature.stopping_probability_function(x) );
        
        p.use_temperature_based_stopping = true;
        
    % pipeline
    
        p.use_direct_scout_to_workspace_pipe = false; % hides stochastic agent stuff a bit, more comparable to other methods     
        p.agent_pool_cleanup = [];
        p.agent_pool_cleanup.agents_interested_in_found_objects = true;
        p.agent_pool_cleanup.agents_with_stale_history = true;
        p.refresh_agent_pool_after_workspace_change = false;
    
    p.salience_model = hmaxq_model_initialize();
        
    % distribution settings

        p.use_distribution_tweaking = false;
        % determines if you tweak distributions for an object based on an
        % instance of that object being checked into the workspace. ie, found a
        % dog? look for a better dog box right around the found dog box.
        %
        % superceded by using conditional distributions. need to nail down
        % this relationship more clearly.

        %p.use_conditional_distributions_xy = false;
        %p.use_conditional_distributions_wh = false;

        % when object a is checked into the workspace, the distribution for
        % objects b and c are updated to be conditional on that found object a.
        %p.use_salience_conditional_product = false;

    p.classification_options = { ...
        'IOU-oracle',...
        'noisy-oracle',...
        'HOG-SVM',...
        'crop_generator',...
        'CNN-SVM',...
        'Finetuned-CNN'};
        
    p.location_method_options_before = { ...
        'uniform', ...
        'noise' ...
        'salience', ...
        'salience_blurry', ...
        'salience_center_surround'};
        
    p.location_method_options_after = { ...
        'uniform', ...
        'noise' ...
        'salience', ...
        'salience_blurry', ...
        'salience_center_surround', ...
        'mvn_conditional', ...
        'mvn_conditional_and_salience'};
    
    p.location_sampling_method_options = { ...
        'sampling', ...
        'sampling_mvn_fast',...
        'ior_sampling', ...
        'ior_peaks' };
    
    p.inhibition_method_options = {'blackman','disk'};
    
    p.box_method_options_before = {   ...
        'independent_uniform_log_aa', ...
        'independent_uniform_log_wh', ...
        'independent_uniform_aa',     ...
        'independent_uniform_wh',     ...
        'independent_normals_log_aa', ...
        'independent_normals_log_wh', ...
        'independent_normals_aa',     ...
        'independent_normals_wh' };
    
    p.box_method_options_after = {    ...
        'independent_uniform_log_aa', ...
        'independent_uniform_log_wh', ...
        'independent_uniform_aa',     ...
        'independent_uniform_wh',     ...
        'independent_normals_log_aa', ...
        'independent_normals_log_wh', ...
        'independent_normals_aa',     ...
        'independent_normals_wh',     ...
        'conditional_mvn_wh',         ...
        'conditional_mvn_aa',         ...
        'conditional_mvn_log_wh',     ...
        'conditional_mvn_log_aa' };
    
    % default values
    
        p.classification_method = 'IOU-oracle';
    
        p.box_method_before_conditioning = 'independent_normals_log_aa';
        p.box_method_after_conditioning  = 'conditional_mvn_log_aa';
        
        p.location_sampling_method_before_conditioning = 'sampling';
        p.location_sampling_method_after_conditioning  = 'sampling';
        
        p.location_method_before_conditioning = 'salience_blurry';
        p.location_method_after_conditioning  = 'mvn_conditional_and_salience';
        
        p.inhibition_method = 'blackman';
        p.inhibition_size = .3 * sqrt(p.image_redim_px); % ~75px for a 256x256 image
        
        p.inhibition_intensity = .5;
        
        % this decides if we'll ad some padding to the xy distribution.
        % Otherwise, it might have a lot of zero regions that aren't searched,
        % preventing the model from falling back on an exhaustive search
        p.dist_xy_padding_value = .05; % assume dist_xy map is in [0,1] before this happens
      
    % population and running settings
    
        p.num_iterations = 10000;

        % these are now set per-objecty type in the
        % situate_situation_definitions
        %p.object_type_priority_before_example_is_found = 1;
        %p.object_type_priority_after_example_is_found  = 0;
        % decide how hard to look for things that have already been found. If
        % set to 0, then no new scouts will be generated looking for that
        % object type. the priority scores are included in a roulette wheel
        % sampling procedure, so they'll be normalized then. don't worry about
        % units.

        p.agent_urgency_defaults.scout    = 1;
        p.agent_urgency_defaults.reviewer = 5;
        p.agent_urgency_defaults.builder  = 10;
        p.num_scouts = 10;
        % a low number of scouts clears out scouts looking for something that's
        % already been found, and increases the relative likelihood of picking
        % reviewers and builders in the pool.

        p.thresholds = [];
        p.thresholds.internal_support = .25;
        p.thresholds.total_support_provisional = .6; % (conditioning happens, but search continues)
        p.thresholds.total_support_final       = .9;  % (search ends)
        
    % visualization options

        p.show_visualization_on_iteration = false;
        p.show_visualization_on_workspace_change = false;
        p.show_visualization_on_end = false;
        p.show_visualization_on_iteration_mod = 1;
        p.start_paused = true;
        
        
    end







