function model_out = uniform_normal_mix_condition( model_in, varargin )

    object_type = varargin{1};
    workspace   = varargin{2};

    if isempty( setsub( workspace.labels, object_type) )
    
        % then all we have in the workspace is the object_type, so don't
        % condition
        model_out = model_in;
    
    else
        
        model_out = situation_models.normal_condition( model_in, object_type, workspace );
      
    end

end
        
         
    
    
    
    
    
    
    
    
    
    
    
        