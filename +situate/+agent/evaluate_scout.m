
function [agent_pool,d,updated_agent] = evaluate_scout( agent_pool, agent_index, p, d, im, label_struct, learned_models ) 
% [agents_out, updated_distribution_structure,updated_agent ] = agents.evaluate_scout( agent_pool, agent_index, param_struct, dist_struct, image, label_file, learned_models );
%
% a few different behaviors depending on what the scout has coming in.
%
% if has an interest and a location already assigned, just apply classifier
% if has an interest and no location, sample a location and apply classifier
% if has no interest and no location, sample both and apply classifier all classes, pick best
% if has no interest but does have a location, then this is a priming box, so we'll eval for
%   each object type (at a computational discount, as the classifiers will all have the same
%   expensive feature transform)

    cur_agent = agent_pool(agent_index); % for convenience. will be put back into the pool array after
    
    has_interest = ~isempty( cur_agent.interest );
    has_box      = ~isempty( cur_agent.box.r0rfc0cf );
    
    sample_interest = false;
    sample_box      = false;
    update_density  = false;

    if has_interest &&  has_box
        % no sampling to do, just eval density
        sample_interest = false;
        sample_box      = false;
        update_density  = true;
        
    elseif has_interest && ~has_box
        % sample box for that interest type
        sample_interest = false;
        sample_box      = true;
        update_density  = true;
        
    elseif ~has_interest && has_box
        % eval that box for each interest, then finalize the interest
        sample_interest = false;
        sample_box      = false;
        update_density  = false;
        cur_agent.interest = p.situation_objects;
        
    elseif ~has_interest && ~has_box
        % sample an interest, then sample a box for that interest
        sample_interest = true;
        sample_box      = true;
        update_density  = true;
    end
    
    
    
    
    
    if sample_interest
        di = sample_1d( [d.interest_priority], 1 );
        cur_agent.interest = p.situation_objects{ di };
    end
    
    if sample_box
        di = find( strcmp( cur_agent.interest, p.situation_objects ) );
        if nargout(p.situation_model.sample) == 2
            % no change to dist struct
            [sampled_box_r0rfc0cf] = p.situation_model.sample( d(di).distribution, d(di).interest, 1, [size(im,1), size(im,2)] ); 
        else
            % with change to dist struct
            %   this isn't used right now, but a sampling process with memory would use it (eg, a
            %   salience map with inhibition of return )
            [sampled_box_r0rfc0cf, ~, d(di).distribution] = p.situation_model.sample( d(di).distribution, d(di).interest, 1, [size(im,1), size(im,2)] ); 
        end
        
        % check the box, add to the agent
        [~, ...
         cur_agent.box.r0rfc0cf, ...
         cur_agent.box.xywh, ...
         cur_agent.box.xcycwh, ...
         cur_agent.box.aspect_ratio, ...
         cur_agent.box.area_ratio] = box_fix( sampled_box_r0rfc0cf, 'r0rfc0cf', [size(im,1) size(im,2)] );
    end
    
    % density evaluation happens here so any changes to the box are taken into account
    if update_density && ~isempty( d )
        di = find(strcmp({d.interest},cur_agent.interest));
        [~, cur_agent.support.sample_densities]       = p.situation_model.sample( d(di).distribution,  d(di).interest, 1, [size(im,1), size(im,2)], cur_agent.box.r0rfc0cf ); 
        [~, cur_agent.support.sample_densities_prior] = p.situation_model.sample( d(end).distribution, d(di).interest, 1, [size(im,1), size(im,2)], cur_agent.box.r0rfc0cf ); 
    end
    
    assert( isequal( cur_agent.type, 'scout' ) );
    assert( ~isempty( cur_agent.box.r0rfc0cf ) );
    assert( ~isempty( cur_agent.interest ) );

    
    

    
    % figure out the internal support
    
        if iscell(cur_agent.interest)
            
            % If the agent has multiple interests, then we should eval for all of them and pick one.
            %
            % The apply function should keep track of being called with the same image and
            % box more than once, so it can keep the expensive feature transform as a persistent 
            % variable and avoid recomputing it.
            % The only thing scaling with interests is the classification layer, not the feature
            % transform.
            
            classification_scores = zeros(1,length(cur_agent.interest));
            for oi = 1:length(cur_agent.interest)
                classification_scores(oi) = p.classifier.apply(  ...
                    learned_models.classifier_model, ...
                    cur_agent.interest{oi}, ...
                    im, ...
                    cur_agent.box.r0rfc0cf, label_struct );
            end
            [~,winning_oi] = max( classification_scores );
            classification_score = classification_scores(winning_oi);
            cur_agent.interest = cur_agent.interest{winning_oi};
            
            % Now that we have an interest, we can eval the box density w/ respect to that interest.
            di = find(strcmp({d.interest},cur_agent.interest));
            [~, cur_agent.support.sample_densities] = p.situation_model.sample( d(di).distribution, d(di).interest, 1, [size(im,1), size(im,2)], agent_pool(agent_index).box.r0rfc0cf ); 
        
        elseif isnan(cur_agent.support.internal) || isempty(cur_agent.support.internal)
        
            classification_score = p.classifier.apply(  ...
                learned_models.classifier_model, ...
                cur_agent.interest, ...
                im, ...
                cur_agent.box.r0rfc0cf, label_struct );
            
        else
            
            classification_score = cur_agent.support.internal;
            % warning('called situate.agent.evaluate_scout on an agent that already had an internal support score');
            
        end
    
        %internal_support_adjustment = @(x) floor(x * 100)/100; % rounding to nearest .01 for consistency between display and internal behavior
        internal_support_adjustment = @(x) x;
        cur_agent.support.internal = internal_support_adjustment( classification_score );
    
        
        
    % figure out GROUND_TRUTH support
    % getting it for displaying progress during a run, or if we're using IOU-oracle as our eval method
    
        if ~isempty(label_struct) && ismember( cur_agent.interest, label_struct.labels_adjusted )
            relevant_label_ind = find(strcmp(cur_agent.interest,label_struct.labels_adjusted),1,'first');
            ground_truth_box_r0rfc0cf = label_struct.boxes_r0rfc0cf(relevant_label_ind,:);
            cur_agent.support.GROUND_TRUTH = intersection_over_union( cur_agent.box.r0rfc0cf, ground_truth_box_r0rfc0cf, 'r0rfc0cf', 'r0rfc0cf' );
            cur_agent.GT_label_raw = label_struct.labels_raw{relevant_label_ind};
        else
            cur_agent.support.GROUND_TRUTH = nan;
            cur_agent.GT_label_raw = '';
        end
        
        
        
    % upate the agent pool based on what we found
    
        % replace the agent in the agent pool
        agent_pool(agent_index) = cur_agent;
        
        % consider adding a reviewer to the pool
        if cur_agent.support.internal >= p.thresholds.internal_support
            agent_pool(end+1) = cur_agent;
            agent_pool(end).type = 'reviewer';
            agent_pool(end).urgency = p.agent_urgency_defaults.reviewer;
        end
        
        updated_agent = cur_agent;
    
end
