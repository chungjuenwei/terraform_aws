**AWS Cognito PoC with Static HTML App**

This repository
showcases a Proof of Concept (PoC) integrating **AWS
Cognito** for user authentication with a simple static HTML application.
The app uses Cognito’s Hosted UI for login and logout functionality and
connects authenticated users to an S3 bucket via Cognito Identity Pools. The
entire setup is managed with **Terraform**,
making it repeatable and easy to deploy.

**🎉 What I Learned and Achieved**

Through this PoC,
I’ve gained valuable insights and successfully implemented a range of features
and configurations. Here’s a breakdown of my learnings and accomplishments:

**1. Terraform for AWS Cognito Setup**

- Provisioned a **Cognito User Pool** to handle user management.
- Configured a **User Pool Client** to link the app with the User Pool.
- Set up a **User Pool Domain** to enable Cognito’s Hosted UI for authentication.
- Managed all AWS resources with Terraform, ensuring a fully reproducible infrastructure.

**2. Static HTML App with Cognito Integration**

- Developed a lightweight static app with three core pages:
    - index.html: Entry page with login/register options.
    - logged_in.html: Post-login page displaying an S3 file list.
    - logged_out.html: Confirmation page after logout.
- Integrated Cognito by redirecting users to the Hosted UI and handling authentication callbacks.

**3. User Management and Security**

- Disabled public signups to restrict access, allowing only admin-created users.
- Mastered **CSV user imports** for efficient bulk user management.
- Configured the User Pool to use **email as usernames** with auto-verified email settings.

**4. S3 Integration with Cognito Identity Pools**

- Established a **Cognito Identity Pool** to provide temporary AWS credentials to authenticated users.
- Created an **IAM role** granting read access to a designated S3 bucket.
- Added JavaScript to logged_in.html to securely list S3 bucket contents post-login.

**5. Customization of Cognito Hosted UI**

- Personalized the Hosted UI with:
    - A **custom logo** for branding.
    - **CSS styling** to tweak backgrounds, buttons, and overall appearance.
- Managed UI customizations via Terraform for consistency across deployments.

**6. Troubleshooting and Debugging**

- Overcame challenges like:
    - OAuth misconfigurations in the User Pool Client.
    - Token handling issues in the static app.
    - Region mismatches and IAM permission errors.
    - CORS setup for seamless S3 access from the browser.

**🚀 Key Features Implemented**

- **User Authentication**: Seamless login/logout via Cognito Hosted UI with proper redirects.
- **Secure S3 Access**: Authenticated users can view files in a private S3 bucket using temporary credentials.
- **Customized UI**: Styled login page with a custom logo and CSS for a polished user experience.
- **Infrastructure as Code**: Terraform drives the deployment of all AWS resources for simplicity and scalability.

**📚 Learnings Summary**

- **AWS Cognito Fundamentals**: Grasped the interplay of User Pools, Clients, and Domains for authentication.
- **Terraform Proficiency**: Leveraged Terraform to provision and manage cloud resources effectively.
- **Static App Challenges**: Adapted a static HTML app to handle dynamic authentication and AWS SDK interactions.
- **Security Practices**: Applied secure access controls using Identity Pools and IAM roles.
- **UI Customization**: Learned to enhance the Hosted UI to align with the app’s branding.

This PoC lays a
strong groundwork for future AWS Cognito projects, proving out both
authentication and authorization in a straightforward, successful
implementation. Great job on getting this up and running!