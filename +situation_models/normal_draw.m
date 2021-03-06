function h = normal_draw( d, object_string, viz_spec, input_agent, box_format_arg, is_initial_draw  )
% h = normal_draw(        d, object_string, viz_spec, input_agent, format_arg, [box_r0rfc0cf], [box_format_arg], [is_initial_draw] );
%
%   what to draw can be 'xy', 'shape', or 'size'
%       xy will be a heat map the shape of the image
%       shape will be a single dimensional distribution of log aspect ratio
%       size  will be a single dimensional distribution of log area ratio
%   each is marginalized from the full sized distribution
%
%   if input_agent and format_arg are included, the figure will also
%   include a representation of the sample (as a point or box) indicating the location or desnity 
%   of that sample

    h = situation_models.uniform_normal_mix_draw( d, object_string, viz_spec, input_agent, box_format_arg, is_initial_draw  );
    
end
                    
                    
                 
            
        
        


        
        
