function models = create_cnn_svm_models_iterative( training_images, p )
%UNTITLED Summary of this function goes here

    p.use_nn_model = false;
    num_negs_per_image = 3;
    
    for type = 1:numel(p.situation_objects)
        
        disp(['Creating CNN-SVM model for ' p.situation_objects{type}]);

        data   = nan((num_negs_per_image+1)*length(training_images),4096);
        labels = cell((num_negs_per_image+1)*length(training_images),1);
        cur_row = 1;
        
        for imi = 1:length(training_images)
        
            [positive, negative] = situate_crop_extractor(training_images{imi}, p.situation_objects(type), p, num_negs_per_image);
            
            if ~isempty(positive)
                positive_features = cnn_features( positive );
                data(cur_row:cur_row+length(positive)-1,:) = positive_features;
                labels(cur_row:cur_row+length(positive)-1) = repmat({'pos'},length(positive),1);
                cur_row = cur_row + length(positive);
            end
            
            if ~isempty(negative)
                negative_features = cnn_features( negative );
                data(cur_row:cur_row+length(negative)-1,:) = negative_features;
                labels(cur_row:cur_row+length(negative)-1) = repmat({'neg'},length(negative),1);
                cur_row = cur_row + length(negative);
            end
            
            progress(imi,length(training_images),'extracting CNN features from images');
            
        end
        
        remove_inds = cellfun(@isempty,labels);
        data(remove_inds,:) = [];
        labels(remove_inds) = [];
            
        if p.use_nn_model
            labels = +strcmp(labels, 'pos');
            nn_model = fitnet([500, 100]);
            nn_model = train(nn_model,data',labels);%,'useParallel','yes','useGPU','yes');
            models{type, 1} = nn_model;
        else
            svm_model = fitcsvm(data, labels, 'Standardize', 'on');
            svm_model = fitSVMPosterior(svm_model);
            models{type, 1} = svm_model.compact;
        end
%       models{type, 2} = feature_vectors;
    end
    
end

function data = cnn_features( images )
    data = cell2mat(map(images, @(x) cnn.cnn_process(x)))';
end
