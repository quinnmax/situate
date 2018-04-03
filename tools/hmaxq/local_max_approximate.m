function y = local_max_approximate( x, d )

    % y = local_max_approximate( x, d );
    %
    % returns the L200 norm of local regions of x (within a disk of
    % diameter d), which looks a lot like a local max, but is a lot faster
    % if you want the full thing. if you're okay for sub_sampling, you can
    % just use local_max and it'll probably be faster.

    p = 200;
    mask = disk(d);
    xp = x.^p;
    temp = conv2( xp, mask, 'same');
    y = temp .^ (1/p);

end