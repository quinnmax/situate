function h = uniform_normal_mix_draw( d, object_string, viz_spec, samples_respresented, samples_represented_formatting, is_initial_draw  )
% h = uniform_normal_mix_draw(        d, object_string, viz_spec, input_agent_or_box, is_initial_draw );
%
%   what to draw can be 'xy', 'shape', or 'size'
%       xy will be a heat map the shape of the image
%       shape will be a single dimensional distribution of log aspect ratio
%       size  will be a single dimensional distribution of log area ratio
%   each is marginalized from the full sized distribution
%
%   if input_agent and/or box_r0rfc0cf are include,
%   a representation of the sample (as a point or box) indicating the location or desnity 
%   of that sample will be included in the figure

    if ~isempty(samples_respresented) 
        %box_r0rfc0cf = input_agent.box.r0rfc0cf;
        box_r0rfc0cf = samples_respresented;
    end

    if ~exist('initial_draw','var') || isempty(is_initial_draw)
        is_initial_draw = false;
    end

    i = find(strcmp( {d.interest}, object_string ));
    im_r = d(i).image_size(1);
    im_c = d(i).image_size(2);

    h = [];

    mu    = d(i).distribution.mu;
    Sigma = d(i).distribution.Sigma;

    % figure out offset for objects in distribution
    if ~d(i).distribution.is_conditional
        params_per_obj = length( d(i).distribution.parameters_description );
        block_ind_0 = params_per_obj * ( find( strcmp( object_string, d(i).distribution.situation_objects)) - 1 );
    else
        block_ind_0 = 0;
    end

    persistent prev_distribution_struct; % stores a copy of the most recently draw dist struct, for comparison
    persistent up_to_date_fig_inds; % an array that lets us know which obj visualizations are up-to-date

    switch viz_spec

        case 'xy'

            % visualize the distribution of box centers
            
            if ~is_initial_draw && ~isempty(prev_distribution_struct) && isequal(d,prev_distribution_struct) && ismember( i, up_to_date_fig_inds )
                % no need to redraw
                % the majority of calls fall into this category
            else

                % define a uniform component
                
                uniform_viz = ones(im_r,im_c);
                
                % define the normal component
                
                rc_ind = strcmp( d(i).distribution.parameters_description, 'rc' ); % row-center ind
                cc_ind = strcmp( d(i).distribution.parameters_description, 'cc' ); % column-center ind
                inds_want = block_ind_0 + find(any([ rc_ind; cc_ind ]));
                inds_have = [];
                data_have = [];
                [mu_bar, Sigma_bar] = mvn_marginalize_and_condition( mu, Sigma, inds_want, inds_have, data_have );
                lsf = sqrt( 1 / (im_r * im_c ) ); % linear scaling factor
                x_vals = linspace( im_c * lsf * -.5, im_c * lsf * .5, im_c );
                y_vals = linspace( im_r * lsf * -.5, im_r * lsf * .5, im_r );
                [X, Y] = meshgrid( x_vals, y_vals );
                Z_flat = mvnpdf( [Y(:) X(:)], mu_bar, Sigma_bar );
                Z = reshape( Z_flat,im_r, im_c );
                mvn_viz = Z;
                
                % figure out the mix
                
                if d(i).distribution.is_conditional
                    if isfield( d(i).distribution, 'p_uniform_post_conditioning' )
                        alpha = d(i).distribution.p_uniform_post_conditioning;
                    else
                        alpha = 0;
                    end
                else
                    if isfield( d(i).distribution, 'p_uniform_pre_conditioning' )
                        alpha = d(i).distribution.p_uniform_pre_conditioning;
                    else
                        alpha = 0;
                    end
                end
                
                % this is just a general representation. the matgray on the normal distorts this
                % substantially, and the alpha should be pretty small compared to the normal
                % component, despite accounting for a lot of the total mass
                final_viz = (1-alpha) * mat2gray(mvn_viz) + alpha * uniform_viz;
                
                if median(final_viz(:)) > .95
                    % a constant 1 for the uniform distribution is jarring, so make it .5
                    final_viz = final_viz * .5;
                end
                    
                
                % draw
                
                imshow(final_viz);
                
                if ~isequal(prev_distribution_struct,d)
                    prev_distribution_struct = d;
                    up_to_date_fig_inds   = [];
                end

                up_to_date_fig_inds = unique([up_to_date_fig_inds i]);

            end

            if exist('box_r0rfc0cf','var') && ~isempty(box_r0rfc0cf)

                % if we're drawing a workspace box and an agent
                % box, and they're the same, we should just draw
                % one of them. The first one is the workspace box,
                % so we'll do that.
                boxes_to_draw = size(box_r0rfc0cf,1);
                if boxes_to_draw > 1 && isequal( box_r0rfc0cf(1,:), box_r0rfc0cf(2,:) ), boxes_to_draw = 1; end
                if ~exist('samples_represented_formatting','var') || isempty(samples_represented_formatting), samples_represented_formatting = 'b'; end

                h = zeros(1,boxes_to_draw);
                for bi = 1:boxes_to_draw
                    hold on; 
                    if iscell(samples_represented_formatting)
                        h(bi) = draw_box( box_r0rfc0cf(bi,:), 'r0rfc0cf', samples_represented_formatting{bi} );
                    else
                        h(bi) = draw_box( box_r0rfc0cf(bi,:), 'r0rfc0cf', samples_represented_formatting );
                    end
                    hold off
                end
            end

        case 'shape'

            aspect_ind = strcmp( d(i).distribution.parameters_description, 'log aspect ratio' );
            inds_want  = block_ind_0 + find(aspect_ind);
            inds_have = [];
            data_have = [];
            [mu_bar, Sigma_bar] = mvn_marginalize_and_condition( mu, Sigma, inds_want, inds_have, data_have );
            sigma_bar = sqrt(Sigma_bar);
            x_vals = linspace( mu_bar - 5*sigma_bar, mu_bar + 5*sigma_bar, 300 );
            y_vals = normpdf( x_vals, mu_bar, sigma_bar );
            plot(x_vals,y_vals,'-b');
            xlim([-2,2]);
            h_temp = gca;
            h_temp.XTick      = [ log(.25)  log(.5) log(1) log(2) log(4) ];
            h_temp.XTickLabel = { '1:4' '1:2' '1:1' '2:1' '4:1'};
            xlabel('shape (W:H)');

            if exist('box_r0rfc0cf','var') && ~isempty(box_r0rfc0cf)

                boxes_to_draw = size(box_r0rfc0cf,1);
                if boxes_to_draw > 1 && isequal( box_r0rfc0cf(1,:), box_r0rfc0cf(2,:) ), boxes_to_draw = 1; end
                if ~exist('samples_represented_formatting','var') || isempty(samples_represented_formatting), samples_represented_formatting = 'ob'; end

                for bi = 1:boxes_to_draw
                    r0 = box_r0rfc0cf(bi,1);
                    rf = box_r0rfc0cf(bi,2);
                    c0 = box_r0rfc0cf(bi,3);
                    cf = box_r0rfc0cf(bi,4);
                    width  = cf - c0 + 1; 
                    height  = rf - r0 + 1;
                    x_val = log(width/height);
                    y_val = normpdf( x_val, mu_bar, sigma_bar );
                    hold on;
                    if iscell(samples_represented_formatting)
                        plot( x_val, y_val, ['o' samples_represented_formatting{bi}(end)] );
                    else
                        plot( x_val, y_val, ['o' samples_represented_formatting(end)]);
                    end
                    hold off
                end
            end

        case 'size'

            area_ind = strcmp( d(i).distribution.parameters_description, 'log area ratio' );
            inds_want = block_ind_0 + find(area_ind);
            inds_have = [];
            data_have = [];
            [mu_bar, Sigma_bar] = mvn_marginalize_and_condition( mu, Sigma, inds_want, inds_have, data_have );
            sigma_bar = sqrt(Sigma_bar);
            x_vals = linspace( mu_bar - 5*sigma_bar, mu_bar + 5*sigma_bar, 300 );
            y_vals = normpdf( x_vals, mu_bar, sigma_bar );
            plot(x_vals,y_vals,'-b');
            xlim([-7,0.5]);
            h_temp = gca;
            h_temp.XTick = [ log(.001) log(.01) log(.1)   log(.5) log(1) ];
            h_temp.XTickLabel = {'.001' '.01' '.1'   '.5' '1'};
            xlabel('area (box/image)');

            if exist('box_r0rfc0cf','var') && ~isempty(box_r0rfc0cf)

                boxes_to_draw = size(box_r0rfc0cf,1);
                if boxes_to_draw > 1 && isequal( box_r0rfc0cf(1,:), box_r0rfc0cf(2,:) ), boxes_to_draw = 1; end
                if ~exist('box_format_arg','var') || isempty(samples_represented_formatting), samples_represented_formatting = 'ob'; end

                for bi = 1:boxes_to_draw
                    r0 = box_r0rfc0cf(bi,1);
                    rf = box_r0rfc0cf(bi,2);
                    c0 = box_r0rfc0cf(bi,3);
                    cf = box_r0rfc0cf(bi,4);
                    width  = cf - c0 + 1; 
                    height  = rf - r0 + 1;
                    x_val = log( (width*height) / (im_r*im_c) );
                    y_val = normpdf( x_val, mu_bar, sigma_bar );
                    hold on;
                    assert( y_val > 0 );
                    if iscell(samples_represented_formatting)
                        plot( x_val, y_val, ['o' samples_represented_formatting{bi}(end)] );
                    else
                        plot( x_val, y_val, ['o' samples_represented_formatting(end)]);
                    end
                    hold off
                end

            end

        otherwise
            warning(['unrecognized viz spec: ' viz_spec]);
            
    end
        
end

                    
                    
               
        
        


        
        
