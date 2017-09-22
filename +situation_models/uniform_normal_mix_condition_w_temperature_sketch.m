function model_out = uniform_normal_mix_condition_w_temperature_sketch( model_in, object_type, workspace )
% model_out = uniform_normal_mix_condition_w_temperature_sketch( model_in, object_type, workspace )
%
% uses workspace and run status to decide how we think this run is going, and how much to emphasize what we have vs what
% exploring the image at random (ie, shift the probability of sampling from uniform after
% conditioning)

    if isempty( setsub( workspace.labels, object_type) )
    
        % then all we have in the workspace is the object_type, so don't
        % condition
        model_out = model_in;
    
    else
        
        model_out = situation_models.normal_condition( model_in, object_type, workspace );
           
            % decide how we think this run is going, and how much to emphasize what we have vs what
            % exploring the image at random
            run_status = '';
            
            num_objects_found = length( setsub( workspace.labels, object_type ) );
            objects_found_ratio = num_objects_found / ( length(model_in.situation_objects) - 1 );
            if objects_found_ratio <= .5
                run_status = [run_status 'few_objects:'];
            else
                run_status = [run_status 'most_objects:'];
            end
            
            total_support_vect = workspace.total_support;
            total_support_vect( strcmp(object_type,workspace.labels) ) = [];
            cur_support_level = prod( total_support_vect + .01 ) ^ (1/numel(total_support_vect));
            if cur_support_level <= .5
                run_status = [run_status 'low_support:'];
            else
                run_status = [run_status 'high_support:'];
            end
            
            if workspace.temperature <= .5
                run_status = [run_status 'early_run:'];
            else
                run_status = [run_status 'late_run:'];
            end
            
            high_p      = .9;
            moderate_p  = .75;
            low_p       = .5;
            very_low_p  = .25;
            % some true things
            switch run_status
                case 'few_objects:low_support:early_run:'
                    % 0 0 0
                    probability_of_uniform_after_conditioning = high_p;
                case 'few_objects:low_support:late_run:'
                    % 0 0 1
                    probability_of_uniform_after_conditioning = moderate_p;
                case 'few_objects:high_support:early_run:'
                    % 0 1 0
                    probability_of_uniform_after_conditioning = moderate_p;
                case 'few_objects:high_support:late in run:'
                    % 0 1 1
                    probability_of_uniform_after_conditioning = low_p;
                case 'most_objects:low_support:early_run:'
                    probability_of_uniform_after_conditioning = moderate_p;
                case 'most_objects:low_support:late_run:'
                    % 1 0 1
                    probability_of_uniform_after_conditioning = low_p;
                case 'most_objects:high_support:early_run:'
                    % 1 1 0
                    probability_of_uniform_after_conditioning = low_p;
                case 'most_objects:high_support:late_run:'
                    % 1 1 1
                    probability_of_uniform_after_conditioning = very_low_p;
            end
            
            model_out.probability_of_uniform_after_conditioning = probability_of_uniform_after_conditioning;
        
        % if workspace has some property
        %   model_out.probability_of_uniform_after_conditioning is something else
        % end
        
    end

end
        
         
    
    
    
    
    
    
    
    
    
    
    
        