

function h = situate_draw_workspace( input, p, workspace )

    % h = situate_draw_workspace( input, p, workspace )
    %
    %   h is the handle to the output figure, specifically the image
    %   input can be an image fname, an image matrix, or a handle to an
    %       exisiting figure
    %   p is a situate parameters structure
    %   workspace is the situate workspace to draw
   

    bounding_box_format_found = 'r';
    bounding_box_format_provisional = 'r--';

    switch class(input)
        case 'char'
            x = imresize_px( imread(input), p.image_redim_px );
            h = imshow( x, [] );
        case 'double'
            if all(ishandle(input))
                axes(input);
                h = input;
            else
                x = imresize_px( input, p.image_redim_px );
                h = imshow( x, [] );
            end
        otherwise
            error('what that?');
    end

    hold on;
    
    % draw workspace boxes onto image
    for wi = 1:size(workspace.boxes_r0rfc0cf,1)
        % designate under .5 iou boxes with a dashed box
        if workspace.internal_support(wi) >= p.thresholds.total_support_final
            h(end+1) = draw_box(workspace.boxes_r0rfc0cf(wi,:), 'r0rfc0cf', bounding_box_format_found);
        else
            h(end+1) = draw_box(workspace.boxes_r0rfc0cf(wi,:), 'r0rfc0cf', bounding_box_format_provisional);
        end
    end

    % then draw the text ( so boxes don't cover text )
    for wi = 1:size(workspace.boxes_r0rfc0cf,1)
        label_text = {...
            workspace.labels{wi};  ...
            ['internal:     ' sprintf( '%0.2f',workspace.internal_support(wi))]; ...
            ['ground truth: ' sprintf( '%0.2f',workspace.GT_IOU(wi))] };
        t1 = text( workspace.boxes_r0rfc0cf(wi,3), workspace.boxes_r0rfc0cf(wi,1), label_text);
        set(t1,'color',[0 0 0]);
        set(t1,'FontSize',14);
        set(t1,'FontWeight','bold');
        t2 = text( workspace.boxes_r0rfc0cf(wi,3)+1, workspace.boxes_r0rfc0cf(wi,1)+1, label_text);
        set(t2,'color',[1 1 1]);
        set(t2,'FontSize',14);
        set(t2,'FontWeight','bold');
        h(end+1) = t1;
        h(end+1) = t2;
    end
    
    hold off;
    
end
