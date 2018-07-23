
function h = gmm_draw( d, object_string, viz_spec, input_agent, box_r0rfc0cf, is_initial_draw  )
% h = gmm_draw(        d, object_string, viz_spec, input_agent, box_r0rfc0cf, is_initial_draw );
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

    if ~isempty(input_agent) 
        %box_r0rfc0cf = input_agent.box.r0rfc0cf;
        box_r0rfc0cf = input_agent;
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

            if ~is_initial_draw && ~isempty(prev_distribution_struct) && isequal(d,prev_distribution_struct) && ismember( i, up_to_date_fig_inds )
                % no need to redraw
            else

                uniform_viz = .5 * ones(im_r,im_c);
                
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
                
                if model.is_conditional
                    alpha = d(i).distribution.p_uniform_post_conditioning;
                else
                    alpha = d(i).distribution.p_uniform_pre_conditioning;
                end
                
                final_viz = (1-alpha) * mat2gray(mvn_viz) + alpha * uniform_viz;
                
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
                if ~exist('box_format_arg','var') || isempty(box_format_arg), box_format_arg = 'b'; end

                h = zeros(1,boxes_to_draw);
                for bi = 1:boxes_to_draw
                    hold on; 
                    if iscell(box_format_arg)
                        h(bi) = draw_box( box_r0rfc0cf(bi,:), 'r0rfc0cf', box_format_arg{bi} );
                    else
                        h(bi) = draw_box( box_r0rfc0cf(bi,:), 'r0rfc0cf', box_format_arg );
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
            %xticks([ log(.25)  log(.5) log(1) log(2) log(4) ]);
            %xticklabels({ '1:4' '1:2' '1:1' '2:1' '4:1'});
            xlabel('shape (W:H)');

            if exist('box_r0rfc0cf','var') && ~isempty(box_r0rfc0cf)

                boxes_to_draw = size(box_r0rfc0cf,1);
                if boxes_to_draw > 1 && isequal( box_r0rfc0cf(1,:), box_r0rfc0cf(2,:) ), boxes_to_draw = 1; end
                if ~exist('box_format_arg','var') || isempty(box_format_arg), box_format_arg = 'ob'; end

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
                    if iscell(box_format_arg)
                        plot( x_val, y_val, ['o' box_format_arg{bi}(end)] );
                    else
                        plot( x_val, y_val, ['o' box_format_arg(end)]);
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
            %xticks([log(.001) log(.01) log(.05)   log(.5) log(1) ]);
            %xticklabels({'.001' '.01' '.05'   '.5' '1'});
            xlabel('area (box/image)');

            if exist('box_r0rfc0cf','var') && ~isempty(box_r0rfc0cf)

                boxes_to_draw = size(box_r0rfc0cf,1);
                if boxes_to_draw > 1 && isequal( box_r0rfc0cf(1,:), box_r0rfc0cf(2,:) ), boxes_to_draw = 1; end
                if ~exist('box_format_arg','var') || isempty(box_format_arg), box_format_arg = 'ob'; end

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
                    if iscell(box_format_arg)
                        plot( x_val, y_val, ['o' box_format_arg{bi}(end)] );
                    else
                        plot( x_val, y_val, ['o' box_format_arg(end)]);
                    end
                    hold off
                end

            end

    end
        
end

                    
                    
                 
            
        
        


        
        






