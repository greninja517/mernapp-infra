pipeline{
    agent any

    environment{
        // GOOGLE_APPLICATION_CREDENTIALS=credentials("gcp_sa_key")
        GITHUB_REPO_URL="https://github.com/greninja517/mernapp-infra.git"
        GIT_DEFAULT_BRANCH = "main"
    }

    parameters{
        choice(name: 'TERRAFORM_ACTION', choices: ['apply', 'destroy'], description: 'Terraform action to perform')
        choice(name: 'TERRAFORM_ENVIRONMENT', choices: ['dev', 'prod'], description: 'Terraform environement to use')
    }

    stages{
        stage("Checkout"){
            steps{
                // Cleanging the workspace
                cleanWs()
                // Checkout the code from the repository
                echo "-------- CHECKING OUT CODE FROM GITHUB --------"
                git branch: "${env.GIT_DEFAULT_BRANCH}", url: "${env.GITHUB_REPO_URL}"
            }          
        }

        stage("GCP Authenctication"){
            steps{
                echo "-------- AUTHENTICATING WITH GCP --------"

                withCredentials([file(credentialsId: 'gcp_sa_key', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
                    sh 'gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS'
                }
            }
        }

        stage("Terraform Init"){
            steps{
                echo "-------- INITIALIZING TERRAFORM --------"

                sh "terraform -chdir=envs/${params.TERRAFORM_ENVIRONMENT}/ init -input=false"
                sh "terraform -chdir=envs/${params.TERRAFORM_ENVIRONMENT}/ validate"
            }
        }

        stage("Terraform Plan"){
            when{
                expression {
                    return params.TERRAFORM_ACTION == 'apply'
                }
            }
            steps{
                echo "-------- CREATING TERRAFORM PLAN --------"
                
                sh "terraform -chdir=envs/${params.TERRAFORM_ENVIRONMENT}/ plan -input=false -out=planfile"
                stash name: "terraform-plan", includes: "envs/${params.TERRAFORM_ENVIRONMENT}/planfile"
            }
        }

        stage("Terraform Apply"){
            when{
                expression {
                    return params.TERRAFORM_ACTION == 'apply'
                }
            }
            steps{
                echo "-------- APPLYING TERRAFORM PLAN --------"
                script{
                    unstash 'terraform-plan'
                    input message: 'Do you want to apply the Terraform plan? Resources will be provisioned after this step', ok: 'Apply'
                    sh "terraform -chdir=envs/${params.TERRAFORM_ENVIRONMENT}/ apply -input=false planfile"
                }
            }
        }

        stage("Terraform Destroy"){
            when{
                expression {
                    return params.TERRAFORM_ACTION == 'destroy'
                }
            }
            steps{
                echo "-------- DESTROYING TERRAFORM RESOURCES --------"

                script{
                    input message: 'Do you want to destroy the Terraform resources? This will remove all resources created by Terraform. This action cannot be reversed.', ok: 'Destroy'
                    sh "terraform -chdir=envs/${params.TERRAFORM_ENVIRONMENT}/ destroy -input=false -auto-approve"
                }
            }
        }
    }

    post {
        always {
            echo 'Pipeline finished.'
        }
        success {
            echo 'Pipeline succeeded!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}