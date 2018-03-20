function workspace = workspace_update_support( workspace, p, dist_structs, learned_models  )
                
    for wi = 1:length(workspace.labels)

        oi = strcmp( workspace.labels{wi},p.situation_objects);

        % the sampling function has the option to include a point, in which case it just
        % returns the density associated with that point.
        [~,new_density] = p.situation_model.sample( dist_structs(oi).distribution, workspace.labels{wi}, 1, dist_structs(1).image_size, workspace.boxes_r0rfc0cf(wi,:) );

        % update external support
        if length(p.external_support_function) == 1
            workspace.external_support(wi) = p.external_support_function( new_density );
        elseif length(p.external_support_function) == length(p.situation_objects) % we have different functions for each object type
            workspace.external_support(wi) = p.external_support_function{oi}( new_density );
        else
            error('number of external support functions is incompatible with the number of situation objects');
        end

        % update total support
        if length(p.total_support_function) == 1
            workspace.total_support(wi) = p.total_support_function( workspace.internal_support(wi), workspace.external_support(wi), learned_models, oi );
        elseif length(p.total_support_function) == length(p.situation_objects)  % we have different functions for each object type
            workspace.total_support(wi) = p.total_support_function{oi}( workspace.internal_support(wi), workspace.external_support(wi), learned_models, oi );
        else
            error('number of total support functions is incompatible with the number of situation objects');
        end

    end

end