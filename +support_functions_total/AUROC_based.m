function support = AUROC_based( internal, external, varargin )
% support = AUROC_based( internal, external, learned_models, object_index );


    % some examples
    % all pretty reliable classifiers, AUROCs = [.98  .95  .90]
    %                              w_internal = [.86  .81  .72]
    %
    % two good, one bad, AUROCs = [.90  .90  .50]
    %                w_internal = [.86  .86  .69]
    %
    % one good, two not so good, AUROCs = [.90  .70  .70]
    %                        w_internal = [.86  .77  .77]
    %
    % all pretty bad, AUROCs = [.65  .65  .65]
    %             w_internal = [.80  .80  .80] % still need to be able to get something into the
    %             workspace, so don't want to totally crash the internal support scores
    

    learned_models = varargin{1};
    oi = varargin{2};
    
    AUROCs = learned_models.classifier_model.AUROCs;
    
    internal_reliablility_scores = 2*(AUROCs-.5);
    
    % the plan here is to make the average internal support weight 1-average_external, but to allow for
    % the most reliable classifier to keep a stronger bias toward interal support.
    
    min_external = .10; % per object
    average_external = .20; % over all objects
    
    w_external = min_external + ...
        length(AUROCs) * (average_external-min_external) * ...
        (1-internal_reliablility_scores) / (sum( 1-internal_reliablility_scores));
    
    w_internal = 1 - w_external;
    
    support = w_internal(oi) * internal + w_external(oi) * external;
    
end
            
