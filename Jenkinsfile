#!groovy

node("CCD-worker-02") {
    def project_name = "ftth-gateway-mytelwebsite"
    def kubernetes_namespace = "prod-mytelcore"
    def environment = "prod"
    def helm_version = "0.5.0"
    def cluster_name = "core-system" 
    def module = "api"

    // =================================================================================

    def harbor_host
    def helm_host
    def image_version
    def url
    def helm_template_name

    if (environment == "prod") {
        harbor_host = "${harbor_prod}"
        image_version = "$BUILD_NUMBER"
        helm_template_name = "helm-template"
        url = "/DEPLOY-COMMON/HELM-K8S-DEPLOY-MYTELCORE-DEV/"
    } 

    def docker_prefix = "${harbor_host}/$kubernetes_namespace"

    stage('1.Clone repository') {
        checkout scm
    }

    stage('2.Build image') {
        sh "docker build -t ${docker_prefix}/${project_name}:${image_version}  -f ./cicd/${module}/${environment}/Dockerfile ."
    }

    stage('3. Push image') {
            sh "docker push ${docker_prefix}/${project_name}:${image_version}"
            sh "docker image rm ${docker_prefix}/${project_name}:${image_version}"
        }

    stage('4.Push to Helm') {
        sh "helm repo update"
        sh "helm fetch harbor/${helm_template_name} --version ${helm_version}"
        sh "tar -xvf ${helm_template_name}-${helm_version}.tgz"
        sh "helm create ${project_name}"
        sh "rm -rf ${project_name}/templates/"
        sh "yes | cp -rf ${helm_template_name}/templates/ ${project_name}/"
        sh "yes | cp -rf cicd/${module}/${environment}/deploy-k8s/values.yaml ${project_name}/"
        sh "yes | cp cicd/${module}/${environment}/configmap-k8s/* ${project_name}/"
        sh "sed -i 's|image_version|$docker_prefix/${project_name}:${image_version}|g' ${project_name}/values.yaml"
        sh "sed -i 's/H1/H1${BUILD_NUMBER}/g' ${project_name}/values.yaml"
        sh "sed -i 's/0.1.0/${image_version}/g' ${project_name}/Chart.yaml"                 
        sh "helm template ${project_name}/ --debug > ${project_name}/deploy-${project_name}.yaml "
        sh "tar -cvzf ${project_name}-${image_version}.tgz ${project_name}/"
        sh "helm cm-push ${project_name}-${image_version}.tgz $kubernetes_namespace --insecure --username $username_jenkins --password $pw_jenkins"
        sh "rm -rf ${project_name}-${image_version}.tgz"
        
    }

    stage('5.Deploy to K8s') {
        if (environment == "prod" || environment == "uat") {
            build job: "${url}", parameters: [string(name: 'ProjectName', value: "${project_name}"),
                                              string(name: 'ImageVersion', value: "${image_version}"),
                                              string(name: 'KubernetesNamespace', value: "$kubernetes_namespace"),
                                              string(name: 'ClusterName', value: "${cluster_name}")]
        } else if (environment == "golive") {
            echo "Non CD"
        }
    }
}
