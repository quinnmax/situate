function workspace = workspace_update_support( workspace, p, dist_structs, learned_models  )
                
    for wi = 1:length(workspace.labels)

        oi = strcmp( workspace.labels{wi},p.situation_objects);

        % the sampling function has the option to include a point, in which case it just
        % returns the density associated with that point.
        [~,new_density] = p.situation_model.sample( dist_structs(oi).distribution, workspace.labels{wi}, 1, dist_structs(1).image_size, workspace.boxes_r0rfc0cf(wi,:) );

        % update external support
        if nargin(p.external_support_function) == 1
            workspace.external_support(wi) = p.external_support_function( new_density );
        elseif abs(nargin(p.external_support_function)) == 2
            workspace.external_support(wi) = p.external_support_function( new_density, learned_models, oi );
        else
            error('ext sup thing bad');
        end

        workspace.total_support(wi) = p.total_support_function( workspace.internal_support(wi), workspace.external_support(wi), learned_models, oi );

    end

end