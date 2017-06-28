function h = uniform_location_normal_box_draw( d, object_string, what_to_draw, input_agent, box_format_arg, initial_draw  )
% h = uniform_location_normal_box_draw( d, object_string, what_to_draw, input_agent, format_arg, [box_r0rfc0cf], [box_format_arg], [initial_draw] );
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

    h = situation_models.uniform_normal_mix_draw( d, object_string, what_to_draw, input_agent, box_format_arg, initial_draw  );

end

        
        
