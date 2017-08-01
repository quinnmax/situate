function model_out = uniform_normal_mix_condition( model_in, object_type, workspace )

    if isempty( setsub( workspace.labels, object_type) )
    
        % then all we have in the workspace is the object_type, so don't
        % condition
        model_out = model_in;
    
    else
        
        model_out = situation_models.normal_condition( model_in, object_type, workspace );
        
        % if workspace has some property
        %   model_out.probability_of_uniform_after_conditioning is something else
        % end
        
    end

end
        
         
    
    
    
    
    
    
    
    
    
    
    
        