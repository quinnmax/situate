


%% enumerate boxes

    im = imread('dogwalking1.jpg');
    im = imresize(im,.5);

    %im = rand(200,300,3);
    im_size = [size(im,1) size(im,2)];
    step = sqrt(prod(im_size))/20;
    rcs = linspace( step/2, im_size(1)-step/2, im_size(1)/(step/2));
    ccs = linspace( step/2, im_size(2)-step/2, im_size(2)/(step/2));

    temp = repmat(rcs,1,length(ccs));
    ccs_display = repmat(ccs,1,length(rcs)); 
    rcs_display = sort(temp);

    figure;
    imshow(.35 * im);
    hold on;
    plot(ccs_display,rcs_display,'.','markersize',20)
    hold off;

    
    
%% enumerate box sizes, shapes

%     aspect_ratio = 2.^(linspace( -2, 2, 5)); % aspect ratio
%     size_ratio = 10.^(linspace( log10(.01), log10(.5), 5 )); % area ratio
% 
    aspect_ratios = 1;
    size_ratios = 1/25;
 
    
%%   

    svm_model_path = '/Users/Max/Dropbox/Projects/situate/+cnn/cnn_svm_models_2016.07.27.12.59.00.mat';
    svm_model = load(svm_model_path);

    
    
%% loop through all boxes
tic();
    target_score_map_1 = zeros( length(rcs), length(ccs), length(size_ratios), length(aspect_ratios) );
    target_score_map_2 = zeros( length(rcs), length(ccs), length(size_ratios), length(aspect_ratios) );
    target_score_map_3 = zeros( length(rcs), length(ccs), length(size_ratios), length(aspect_ratios) );

    for sri = 1:length(size_ratios)

        box_area = size_ratios(sri) * im_size(1) * im_size(2);

    for ari = 1:length(aspect_ratios)

        box_w = sqrt( aspect_ratios(ari) * box_area );
        box_h = box_area / box_w;

    for ri = 1:length(rcs)
    for ci = 1:length(ccs)

        r0 = round( rcs(ri) - box_h/2 );
        rf = round( r0      + box_h - 1 );
        c0 = round( ccs(ci) - box_w/2 );
        cf = round( c0      + box_w - 1 );

        r0 = max(r0,1);
        c0 = max(c0,1);
        rf = min(rf,im_size(1));
        cf = min(cf,im_size(2));

        cnn_features = cnn.cnn_process( im(r0:rf,c0:cf,:) );
        
        [~,class_scores] = svm_model.models{1}.predict(cnn_features');
        target_score_map_1(ri,ci,sri,ari) = class_scores(2);
       
        [~,class_scores] = svm_model.models{2}.predict(cnn_features');
        target_score_map_2(ri,ci,sri,ari) = class_scores(2);
        
        [~,class_scores] = svm_model.models{3}.predict(cnn_features');
        target_score_map_3(ri,ci,sri,ari) = class_scores(2);
        
    end
    end
    fprintf('.');
    end
    fprintf('\n');
    toc();
    end
    
    fname_save = ['box_enumeration_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat'];
    save(fname_save);

    
    
%% see how they look

target_score_map_1 = mat2gray(target_score_map_1);

num_sizes  = length(size_ratios);
num_shapes = length(aspect_ratios);

figure('name','class 1');
for i = 1:num_sizes
for j = 1:num_shapes
    subplot2(num_sizes,num_shapes,i,j);
    imshow(squeeze( target_score_map_1(:,:,i,j)));
    if i == 1, title(size_ratios(j)); end
    if j == 1, ylabel(aspect_ratios(i)); end

end
end



target_score_map_2 = mat2gray(target_score_map_2);

figure('name','class 2');
for i = 1:num_sizes
for j = 1:num_shapes
    subplot2(num_sizes,num_shapes,i,j);
    imshow(squeeze( target_score_map_2(:,:,i,j)));
    if i == 1, title(size_ratios(j)); end
    if j == 1, ylabel(aspect_ratios(i)); end

end
end



target_score_map_3 = mat2gray(target_score_map_3);

figure('name','class 3');
for i = 1:num_sizes
for j = 1:num_shapes
    subplot2(num_sizes,num_shapes,i,j);
    imshow(squeeze( target_score_map_3(:,:,i,j)));
    if i == 1, title(size_ratios(j)); end
    if j == 1, ylabel(aspect_ratios(i)); end

end
end







