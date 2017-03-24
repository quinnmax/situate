
function p = parameters_initialize()

    % p = situate_parameters_initialize();
    %
    % lots of options outlined in comments

    p = [];
    p.description = '';
    p.image_redim_px = 500000;
    p.num_iterations = 2000;
    
     % population settings
     
        p.num_scouts = 10;
        p.agent_urgency_defaults.scout    = 1;
        p.agent_urgency_defaults.reviewer = 5;
        p.agent_urgency_defaults.builder  = 10;
        
    % pipeline
    
        p.use_direct_scout_to_workspace_pipe = false; % hides stochastic agent stuff a bit, more comparable to other methods     
        p.agent_pool_cleanup = [];
        p.agent_pool_cleanup.on_object_of_interest_found = true;
        p.agent_pool_cleanup.on_workspace_change = true;
       
    % support functions
    
        % center it at the uniform prior value for the size of the empirical
        % distribution that we're using (i.e. we're using 250000 pixels, so
        % each has a value of 1/250000, so make that the center of the external
        % support activation function).
        p.external_support_function = @(x) sigmoid(   2 * p.image_redim_px * ( x - (1/p.image_redim_px) )     );
        %x = linspace(0, 10 * 1/p.image_redim_px, 100);
        %figure(); plot(x,p.external_support_function(x));
        p.total_support_function = @(internal,external) .75 * internal + .25 * external;
        
    % thresholds
    
        p.thresholds = [];
        p.thresholds.internal_support          = .25;
        p.thresholds.total_support_provisional = .5; % (conditioning happens, but search continues)
        p.thresholds.total_support_final       = .5;  % (search ends)
        
     % visualization options
     
        p.viz_options.on_iteration          = false;
        p.viz_options.on_iteration_mod      = 1;
        p.viz_options.on_workspace_change   = false;
        p.viz_options.on_end                = false;
        p.viz_options.start_paused          = false;
        

%     p.classification_options = { ...
%         'IOU-oracle',...
%         'noisy-oracle',...
%         'HOG-SVM',...
%         'crop_generator',...
%         'CNN-SVM',...
%         'Finetuned-CNN'};
%         
%     p.location_method_options_before = { ...
%         'uniform', ...
%         'noise' ...
%         'salience', ...
%         'salience_blurry', ...
%         'salience_center_surround'};
%         
%     p.location_method_options_after = { ...
%         'uniform', ...
%         'noise' ...
%         'salience', ...
%         'salience_blurry', ...
%         'salience_center_surround', ...
%         'mvn_conditional', ...
%         'mvn_conditional_and_salience'};
%     
%     p.location_sampling_method_options = { ...
%         'sampling', ...
%         'sampling_mvn_fast',...
%         'ior_sampling', ...
%         'ior_peaks' };
%     
%     p.inhibition_method_options = {'blackman','disk'};
%     
%     p.box_method_options_before = {   ...
%         'independent_uniform_log_aa', ...
%         'independent_uniform_log_wh', ...
%         'independent_uniform_aa',     ...
%         'independent_uniform_wh',     ...
%         'independent_normals_log_aa', ...
%         'independent_normals_log_wh', ...
%         'independent_normals_aa',     ...
%         'independent_normals_wh' };
%     
%     p.box_method_options_after = {    ...
%         'independent_uniform_log_aa', ...
%         'independent_uniform_log_wh', ...
%         'independent_uniform_aa',     ...
%         'independent_uniform_wh',     ...
%         'independent_normals_log_aa', ...
%         'independent_normals_log_wh', ...
%         'independent_normals_aa',     ...
%         'independent_normals_wh',     ...
%         'conditional_mvn_wh',         ...
%         'conditional_mvn_aa',         ...
%         'conditional_mvn_log_wh',     ...
%         'conditional_mvn_log_aa' };
    
    % default values
    
%         p.classification_method = 'IOU-oracle';
%     
%         p.box_method_before_conditioning = 'independent_normals_log_aa';
%         p.box_method_after_conditioning  = 'conditional_mvn_log_aa';
%         
%         p.location_sampling_method_before_conditioning = 'sampling';
%         p.location_sampling_method_after_conditioning  = 'sampling';
%         
%         p.location_method_before_conditioning = 'salience_blurry';
%         p.location_method_after_conditioning  = 'mvn_conditional_and_salience';
%         
%         p.inhibition_method = 'blackman';
%         p.inhibition_size = .3 * sqrt(p.image_redim_px); % ~75px for a 256x256 image
%         
%         p.inhibition_intensity = .5;
%         
%         % this decides if we'll ad some padding to the xy distribution.
%         % Otherwise, it might have a lot of zero regions that aren't searched,
%         % preventing the model from falling back on an exhaustive search
%         p.dist_xy_padding_value = .05; % assume dist_xy map is in [0,1] before this happens
        
    end







