
function return_val = situate_parameters_validate( p )

    assert( ismember( p.location_method_before_conditioning, p.location_method_options_before ) );
    assert( ismember( p.location_method_after_conditioning,  p.location_method_options_after ) );
    assert( ismember( p.box_method_before_conditioning, p.box_method_options_before ) );
    assert( ismember( p.box_method_after_conditioning, p.box_method_options_after ) );
    assert( ismember( p.location_sampling_method_before_conditioning, p.location_sampling_method_options ) );
    assert( ismember( p.location_sampling_method_after_conditioning,  p.location_sampling_method_options ) );
    assert( ismember( p.classification_method, p.classification_options));
    
    return_val = true;
    
end



